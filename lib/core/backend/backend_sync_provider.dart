import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/telemetry_data.dart';
import '../network/udp_service.dart';
import '../telemetry/gt7/gt7_parser.dart';
import '../telemetry/telemetry_parser.dart';
import 'backend_client.dart';
import 'backend_config.dart';
import 'session_id_provider.dart';
import 'telemetry_frame_dto.dart';
import 'telemetry_mapper.dart';

enum SyncStatus {
  disabled,
  idle,
  syncing,
  degraded,
  rejected,
  failed,
}

enum SessionAlignmentStatus {
  none,
  pending,
  created,
  failed,
}

class BackendSyncState {
  final String sessionId;
  final SyncStatus status;
  final bool udpConnected;
  final int pendingFrames;
  final int totalSent;
  final int totalAccepted;
  final int totalRejected;
  final int consecutiveFailures;
  final IngestRejection? lastRejection;
  final String? lastErrorMessage;
  final DateTime? lastSyncAt;
  final DateTime? lastErrorAt;

  /// Backend-owned session ID (session_*) when session alignment succeeds.
  /// When null, [sessionId] (local_*) is used for all backend calls.
  final String? backendSessionId;

  /// Whether backend session creation was attempted and its outcome.
  final SessionAlignmentStatus alignmentStatus;

  const BackendSyncState({
    required this.sessionId,
    this.status = SyncStatus.disabled,
    this.udpConnected = false,
    this.pendingFrames = 0,
    this.totalSent = 0,
    this.totalAccepted = 0,
    this.totalRejected = 0,
    this.consecutiveFailures = 0,
    this.lastRejection,
    this.lastErrorMessage,
    this.lastSyncAt,
    this.lastErrorAt,
    this.backendSessionId,
    this.alignmentStatus = SessionAlignmentStatus.none,
  });

  bool get enabled => status != SyncStatus.disabled;
  bool get isOffline => status == SyncStatus.degraded || status == SyncStatus.failed;

  /// Returns the backend session ID when session alignment succeeded,
  /// or the local session ID as fallback.
  String get effectiveSessionId => backendSessionId ?? sessionId;

  BackendSyncState copyWith({
    SyncStatus? status,
    bool? udpConnected,
    int? pendingFrames,
    int? totalSent,
    int? totalAccepted,
    int? totalRejected,
    int? consecutiveFailures,
    Object? lastRejection = _unset,
    String? lastErrorMessage,
    bool clearError = false,
    DateTime? lastSyncAt,
    Object? lastErrorAt = _unset,
    Object? backendSessionId = _unset,
    SessionAlignmentStatus? alignmentStatus,
  }) {
    return BackendSyncState(
      sessionId: sessionId,
      status: status ?? this.status,
      udpConnected: udpConnected ?? this.udpConnected,
      pendingFrames: pendingFrames ?? this.pendingFrames,
      totalSent: totalSent ?? this.totalSent,
      totalAccepted: totalAccepted ?? this.totalAccepted,
      totalRejected: totalRejected ?? this.totalRejected,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastRejection: lastRejection == _unset
          ? this.lastRejection
          : lastRejection as IngestRejection?,
      lastErrorMessage: clearError
          ? null
          : (lastErrorMessage ?? this.lastErrorMessage),
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastErrorAt: lastErrorAt == _unset
          ? this.lastErrorAt
          : lastErrorAt as DateTime?,
      backendSessionId: backendSessionId == _unset
          ? this.backendSessionId
          : backendSessionId as String?,
      alignmentStatus: alignmentStatus ?? this.alignmentStatus,
    );
  }
}

const _unset = Object();

class BackendSyncNotifier extends StateNotifier<BackendSyncState> {
  final BackendClient _client;
  final TelemetryParser _parser;
  final BackendConfig _config;
  StreamSubscription<Uint8List>? _subscription;
  final List<TelemetryData> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  BackendSyncNotifier({
    BackendClient? client,
    TelemetryParser? parser,
    BackendConfig? config,
    UdpService? udpService,
  }) : _client = client ?? BackendClient(),
       _parser = parser ?? Gt7Parser(),
       _config = config ?? const BackendConfig(),
       super(BackendSyncState(
         sessionId: generateLocalSessionId(),
       )) {
    if (udpService != null) {
      connect(udpService);
    }
  }

  void connect(UdpService udpService) {
    _subscription?.cancel();
    _flushTimer?.cancel();
    _subscription = udpService.packetStream.listen(_onPacket);
    state = state.copyWith(udpConnected: true);
    debugPrint(
      '[BackendSync] Connected to UDP stream, session: ${state.sessionId}',
    );
  }

  Future<void> _finishBackendSession() async {
    final backendId = state.backendSessionId;
    if (backendId == null) return;

    try {
      await _client.finishSession(
        backendId,
        FinishSessionRequest(
          endedUnixMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      debugPrint('[BackendSync] Finished backend session: $backendId');
    } on BackendRequestException catch (e) {
      debugPrint(
        '[BackendSync] Finish session error (non-fatal): '
        '${e.error.code} — ${e.error.message}',
      );
    } on Object catch (e) {
      debugPrint('[BackendSync] Finish session unexpected error: $e');
    }
  }

  Future<void> disconnect() async {
    await _finishBackendSession();
    _subscription?.cancel();
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    state = state.copyWith(
      udpConnected: false,
      status: SyncStatus.disabled,
      backendSessionId: null,
      alignmentStatus: SessionAlignmentStatus.none,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled && !state.enabled) {
      await _ensureBackendSession();
      _startFlushTimer();
    } else if (!enabled && state.enabled) {
      await _finishBackendSession();
      _flushTimer?.cancel();
      _flushTimer = null;
      _buffer.clear();
    }
    state = state.copyWith(
      status: enabled ? SyncStatus.idle : SyncStatus.disabled,
      pendingFrames: enabled ? null : 0,
      consecutiveFailures: enabled ? 0 : null,
      lastRejection: null,
      clearError: enabled,
      backendSessionId: enabled ? state.backendSessionId : null,
      alignmentStatus: enabled ? state.alignmentStatus : SessionAlignmentStatus.none,
    );
  }

  /// Attempt to create a backend session when V2 data mode is enabled.
  /// On success, [state.backendSessionId] is set to the backend-owned ID.
  /// On failure, sync continues with the local session ID.
  Future<void> _ensureBackendSession() async {
    if (!_config.useV2Data) return;
    if (state.alignmentStatus == SessionAlignmentStatus.created) return;
    if (state.alignmentStatus == SessionAlignmentStatus.pending) return;

    state = state.copyWith(
      alignmentStatus: SessionAlignmentStatus.pending,
    );

    try {
      final response = await _client.createSession(
        CreateSessionRequest(
          source: 'flutter',
          game: 'gt7',
          platform: 'ps5',
          driverAlias: _config.driverAlias,
          trackId: '',
          startedUnixMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      state = state.copyWith(
        backendSessionId: response.sessionId,
        alignmentStatus: SessionAlignmentStatus.created,
      );
      debugPrint(
        '[BackendSync] Backend session created: ${response.sessionId}',
      );
    } on BackendRequestException catch (e) {
      state = state.copyWith(
        alignmentStatus: SessionAlignmentStatus.failed,
      );
      debugPrint(
        '[BackendSync] Session creation failed (continuing with local ID): '
        '${e.error.code} — ${e.error.message}',
      );
    } on Object catch (e) {
      state = state.copyWith(
        alignmentStatus: SessionAlignmentStatus.failed,
      );
      debugPrint(
        '[BackendSync] Session creation unexpected error (continuing with local ID): $e',
      );
    }
  }

  @visibleForTesting
  void injectPacket(Uint8List bytes) => _onPacket(bytes);

  void _onPacket(Uint8List bytes) {
    if (state.status == SyncStatus.disabled) return;

    final data = _parser.parse(bytes);
    if (data == null) return;

    _buffer.add(data);

    if (_buffer.length >= _config.defaultBatchSize) {
      _flush();
    }
  }

  void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_buffer.isNotEmpty) {
        _flush();
      }
    });
  }

  Future<void> _flush() async {
    if (_isFlushing) return;
    if (_buffer.isEmpty) return;
    _isFlushing = true;

    final batchSize = computeBatchSize(
      availableFrames: _buffer.length,
      defaultBatch: _config.defaultBatchSize,
      maxBatch: _config.maxBatchSize,
    );

    List<TelemetryData> batch;
    List<TelemetryFrameDto> frames;
    List<Map<String, dynamic>> jsonFrames;

    if (batchSize <= 0) {
      _isFlushing = false;
      return;
    }

    batch = List<TelemetryData>.from(_buffer.take(batchSize));
    _buffer.removeRange(0, batchSize);

    frames = mapTelemetryBatch(batch);
    jsonFrames = frames.map((f) => f.toJson()).toList();

    state = state.copyWith(
      status: SyncStatus.syncing,
      pendingFrames: frames.length,
    );

    try {
      final response = await _client.postFrameBatch(
        state.effectiveSessionId,
        jsonFrames,
      );
      final now = DateTime.now();
      state = state.copyWith(
        status: SyncStatus.idle,
        pendingFrames: _buffer.length,
        totalSent: state.totalSent + response.receivedFrames,
        totalAccepted: state.totalAccepted + response.acceptedFrames,
        totalRejected: state.totalRejected + response.rejectedFrames,
        consecutiveFailures: 0,
        lastRejection: null,
        lastErrorMessage: null,
        lastSyncAt: now,
        clearError: true,
        lastErrorAt: null,
      );
      debugPrint(
        '[BackendSync] Flushed ${frames.length} frames — '
        'accepted: ${response.acceptedFrames}, '
        'rejected: ${response.rejectedFrames}',
      );
    } on BackendRequestException catch (e) {
      final now = DateTime.now();
      if (e.error.details != null && e.error.isBadRequest) {
        // Typed validation rejection: drop frames, do NOT retry
        state = state.copyWith(
          status: SyncStatus.rejected,
          pendingFrames: 0,
          totalRejected: state.totalRejected + batch.length,
          consecutiveFailures: 0,
          lastRejection: e.error.details,
          lastErrorMessage: e.error.message,
          lastErrorAt: now,
        );
        debugPrint(
          '[BackendSync] Rejected ${batch.length} frames: '
          '${e.error.code} — ${e.error.message}',
        );
      } else {
        // Network or server error: buffer frames in chronological order
        _buffer.insertAll(0, batch);
        _trimBuffer();
        if (state.status != SyncStatus.failed) {
          state = state.copyWith(
            status: SyncStatus.degraded,
            pendingFrames: _buffer.length,
            consecutiveFailures: state.consecutiveFailures + 1,
            lastRejection: null,
            lastErrorMessage: e.error.message,
            lastErrorAt: now,
          );
        }
        debugPrint(
          '[BackendSync] Flush error — '
          'buffered ${batch.length} frames',
        );
      }
    } on Object catch (e) {
      _buffer.insertAll(0, batch);
      _trimBuffer();
      if (state.status != SyncStatus.failed) {
        state = state.copyWith(
          status: SyncStatus.degraded,
          pendingFrames: _buffer.length,
          consecutiveFailures: state.consecutiveFailures + 1,
          lastRejection: null,
          lastErrorMessage: e.toString(),
          lastErrorAt: DateTime.now(),
        );
      }
      debugPrint(
        '[BackendSync] Flush error — '
        'buffered ${batch.length} frames',
      );
    } finally {
      _isFlushing = false;
    }
  }

  void _trimBuffer() {
    if (_buffer.length <= _config.maxBatchSize * 2) return;
    final overflow = _buffer.length - _config.maxBatchSize;
    _buffer.removeRange(0, overflow);
    state = state.copyWith(
      status: SyncStatus.failed,
      pendingFrames: _buffer.length,
      consecutiveFailures: state.consecutiveFailures + 1,
      lastErrorMessage: 'Buffer overflow: dropped $overflow oldest frames',
      lastErrorAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _flushTimer?.cancel();
    _client.dispose();
    super.dispose();
  }
}

final backendConfigProvider = Provider<BackendConfig>((ref) {
  return const BackendConfig();
});

final backendClientProvider = Provider<BackendClient>((ref) {
  final config = ref.watch(backendConfigProvider);
  return BackendClient(config: config);
});

final backendSyncProvider =
    StateNotifierProvider<BackendSyncNotifier, BackendSyncState>((ref) {
      final client = ref.watch(backendClientProvider);
      final config = ref.watch(backendConfigProvider);
      final notifier = BackendSyncNotifier(
        client: client,
        config: config,
      );
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });
