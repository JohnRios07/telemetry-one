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
  });

  bool get enabled => status != SyncStatus.disabled;
  bool get isOffline => status == SyncStatus.degraded || status == SyncStatus.failed;

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

  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    state = state.copyWith(
      udpConnected: false,
      status: SyncStatus.disabled,
    );
  }

  void setEnabled(bool enabled) {
    if (enabled && !state.enabled) {
      _startFlushTimer();
    } else if (!enabled && state.enabled) {
      _flushTimer?.cancel();
      _flushTimer = null;
    }
    state = state.copyWith(
      status: enabled ? SyncStatus.idle : SyncStatus.disabled,
      consecutiveFailures: enabled ? 0 : null,
      lastRejection: null,
      clearError: enabled,
    );
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

  void _flush() {
    if (_buffer.isEmpty) return;

    final batch = List<TelemetryData>.from(_buffer);
    _buffer.clear();

    final frames = mapTelemetryBatch(batch);
    final jsonFrames = frames.map((f) => f.toJson()).toList();

    state = state.copyWith(
      status: SyncStatus.syncing,
      pendingFrames: frames.length,
    );

    _client
        .postFrameBatch(state.sessionId, jsonFrames)
        .then((response) {
      final now = DateTime.now();
      state = state.copyWith(
        status: SyncStatus.idle,
        pendingFrames: 0,
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
    }).catchError((Object error) {
      final now = DateTime.now();

      if (error is BackendRequestException &&
          error.error.details != null &&
          error.error.isBadRequest) {
        // Typed validation rejection: drop frames, do NOT retry
        state = state.copyWith(
          status: SyncStatus.rejected,
          pendingFrames: 0,
          totalRejected: state.totalRejected + frames.length,
          consecutiveFailures: 0,
          lastRejection: error.error.details,
          lastErrorMessage: error.error.message,
          lastErrorAt: now,
        );
        debugPrint(
          '[BackendSync] Rejected ${frames.length} frames: '
          '${error.error.code} — ${error.error.message}',
        );
      } else {
        // Network or server error after all retries: buffer frames, degrade
        _buffer.insertAll(0, batch);
        _trimBuffer();
        if (state.status != SyncStatus.failed) {
          final message = error is BackendRequestException
              ? error.error.message
              : error.toString();
          state = state.copyWith(
            status: SyncStatus.degraded,
            pendingFrames: _buffer.length,
            consecutiveFailures: state.consecutiveFailures + 1,
            lastRejection: null,
            lastErrorMessage: message,
            lastErrorAt: now,
          );
        }
        debugPrint(
          '[BackendSync] Flush error — '
          'buffered ${batch.length} frames',
        );
      }
    });
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

final backendSyncProvider =
    StateNotifierProvider<BackendSyncNotifier, BackendSyncState>((ref) {
      final notifier = BackendSyncNotifier();
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

final backendConfigProvider = Provider<BackendConfig>((ref) {
  return const BackendConfig();
});

final backendClientProvider = Provider<BackendClient>((ref) {
  final config = ref.watch(backendConfigProvider);
  return BackendClient(config: config);
});
