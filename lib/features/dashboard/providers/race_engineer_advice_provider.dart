import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_client.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../../../../core/backend/v2_bridge_providers.dart';
import 'session_provider.dart';

enum RaceEngineerAdviceStatus {
  idle,
  loading,
  success,
  noEvents,
  rateLimited,
  error,
}

const Duration raceEngineerAdviceRequestTimeout = Duration(seconds: 25);
const Duration raceEngineerAdviceAutoPollInterval = Duration(seconds: 12);
const Duration raceEngineerAdviceAutoPollBackoff = Duration(seconds: 30);

final raceEngineerAdviceRequestTimeoutProvider = Provider<Duration>((ref) {
  return raceEngineerAdviceRequestTimeout;
});

final raceEngineerAdviceAutoPollIntervalProvider = Provider<Duration>((ref) {
  return raceEngineerAdviceAutoPollInterval;
});

final raceEngineerAdviceAutoPollBackoffProvider = Provider<Duration>((ref) {
  return raceEngineerAdviceAutoPollBackoff;
});

class RaceEngineerAdviceAvailability {
  final bool canRequest;
  final String? message;

  const RaceEngineerAdviceAvailability._({
    required this.canRequest,
    this.message,
  });

  const RaceEngineerAdviceAvailability.available() : this._(canRequest: true);

  const RaceEngineerAdviceAvailability.unavailable(String message)
    : this._(canRequest: false, message: message);
}

class RaceEngineerAdviceState {
  final RaceEngineerAdviceStatus status;
  final RaceEngineerAdviceResponse? response;
  final String? message;
  final DateTime? cooldownExpiresAt;

  const RaceEngineerAdviceState({
    this.status = RaceEngineerAdviceStatus.idle,
    this.response,
    this.message,
    this.cooldownExpiresAt,
  });

  const RaceEngineerAdviceState.idle() : this();

  RaceEngineerAdviceState copyWith({
    RaceEngineerAdviceStatus? status,
    RaceEngineerAdviceResponse? response,
    String? message,
    Object? cooldownExpiresAt = _unchanged,
  }) {
    return RaceEngineerAdviceState(
      status: status ?? this.status,
      response: response ?? this.response,
      message: message ?? this.message,
      cooldownExpiresAt: cooldownExpiresAt == _unchanged
          ? this.cooldownExpiresAt
          : cooldownExpiresAt as DateTime?,
    );
  }

  bool isCooldownActive([DateTime? now]) {
    final expiresAt = cooldownExpiresAt;
    return expiresAt != null && expiresAt.isAfter(now ?? DateTime.now());
  }

  int? remainingCooldownSeconds([DateTime? now]) {
    final expiresAt = cooldownExpiresAt;
    if (expiresAt == null) return null;
    final remaining = expiresAt.difference(now ?? DateTime.now());
    if (remaining.inMilliseconds <= 0) return null;
    return (remaining.inMilliseconds / 1000).ceil();
  }
}

const Object _unchanged = Object();

class _RaceEngineerRequestScope {
  final String sessionId;
  final String effectiveSessionId;

  const _RaceEngineerRequestScope({
    required this.sessionId,
    required this.effectiveSessionId,
  });

  bool matches(_RaceEngineerRequestScope other) {
    return sessionId == other.sessionId &&
        effectiveSessionId == other.effectiveSessionId;
  }
}

class RaceEngineerAdviceNotifier
    extends StateNotifier<RaceEngineerAdviceState> {
  final Ref _ref;
  Timer? _cooldownTimer;
  int? _lastSuccessfulSinceUnixMs;
  _RaceEngineerRequestScope? _lastRequestScope;
  _RaceEngineerRequestScope? _activeRequestScope;

  RaceEngineerAdviceNotifier(this._ref)
    : super(const RaceEngineerAdviceState.idle());

  Future<void> requestAdvice({
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  }) async {
    _syncRequestScope();

    if (state.status == RaceEngineerAdviceStatus.loading) return;
    if (state.isCooldownActive()) return;

    final availability = _ref.read(raceEngineerAdviceAvailabilityProvider);
    if (!availability.canRequest) {
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: availability.message ?? 'Start a race to ask the engineer.',
      );
      return;
    }

    final requestScope = _currentRequestScope();
    _activeRequestScope = requestScope;
    final sessionId = requestScope.effectiveSessionId;
    final effectiveRequest = request.sinceUnixMs == null &&
            _lastSuccessfulSinceUnixMs != null
        ? RaceEngineerAdviceRequest(
            sinceUnixMs: _lastSuccessfulSinceUnixMs,
            maxEvents: request.maxEvents,
          )
        : request;
    state = const RaceEngineerAdviceState(
      status: RaceEngineerAdviceStatus.loading,
    );

    try {
      final timeout = _ref.read(raceEngineerAdviceRequestTimeoutProvider);
      final response = await _ref
          .read(backendClientProvider)
          .requestRaceEngineerAdvice(sessionId, effectiveRequest)
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Race Engineer advice request timed out after '
                '${timeout.inSeconds} seconds.',
              );
            },
          );

      if (!_canApplyResponse(response, requestScope)) {
        _discardStaleResponse(requestScope);
        return;
      }

      if (response.hasNoEvents) {
        _updateLastSuccessfulSinceUnixMs(response);
        _clearCooldownTimer();
        state = RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.noEvents,
          response: response,
          message: response.message ?? response.advice,
        );
        return;
      }

      if (response.isRateLimited) {
        final cooldownExpiresAt = _cooldownExpiresAt(response);
        _scheduleCooldownExpiry(cooldownExpiresAt);
        state = RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.rateLimited,
          response: response,
          message: response.message ?? response.advice,
          cooldownExpiresAt: cooldownExpiresAt,
        );
        return;
      }

      _updateLastSuccessfulSinceUnixMs(response);
      _clearCooldownTimer();
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.success,
        response: response,
        message: response.message ?? response.advice,
      );
    } on TimeoutException {
      _clearCooldownTimer();
      state = const RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: 'Race Engineer request timed out. Please try again.',
      );
    } on BackendRequestException catch (e) {
      _clearCooldownTimer();
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: e.error.message,
      );
    } on Exception catch (e) {
      _clearCooldownTimer();
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: e.toString(),
      );
    } on Object catch (error, stackTrace) {
      _clearCooldownTimer();
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'RaceEngineerAdviceNotifier.requestAdvice',
        ),
      );
      state = const RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: 'Unexpected error while requesting Race Engineer advice.',
      );
    } finally {
      if (_activeRequestScope != null && _activeRequestScope!.matches(requestScope)) {
        _activeRequestScope = null;
      }
    }
  }

  @override
  void dispose() {
    _clearCooldownTimer();
    super.dispose();
  }

  DateTime? _cooldownExpiresAt(RaceEngineerAdviceResponse response) {
    final seconds = response.providerInfo?.retryAfterSeconds;
    if (seconds == null || seconds <= 0) return null;
    return DateTime.now().add(Duration(seconds: seconds));
  }

  void _scheduleCooldownExpiry(DateTime? expiresAt) {
    _clearCooldownTimer();
    if (expiresAt == null) return;

    final duration = expiresAt.difference(DateTime.now());
    if (duration.inMilliseconds <= 0) return;

    _cooldownTimer = Timer(duration, () {
      if (!mounted) return;
      if (!state.isCooldownActive()) {
        state = state.copyWith(cooldownExpiresAt: null);
      }
    });
  }

  void _clearCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  void _updateLastSuccessfulSinceUnixMs(RaceEngineerAdviceResponse response) {
    final nextSinceUnixMs =
        response.window?.untilUnixMs ?? response.generatedAtUnixMs;
    if (nextSinceUnixMs == null) return;
    if (_lastSuccessfulSinceUnixMs == null ||
        nextSinceUnixMs > _lastSuccessfulSinceUnixMs!) {
      _lastSuccessfulSinceUnixMs = nextSinceUnixMs;
    }
  }

  void _syncRequestScope() {
    final nextScope = _currentRequestScope();

    if (_lastRequestScope == null || !_lastRequestScope!.matches(nextScope)) {
      _lastSuccessfulSinceUnixMs = null;
      _lastRequestScope = nextScope;
    }
  }

  _RaceEngineerRequestScope _currentRequestScope() {
    final sessionState = _ref.read(sessionRecorderProvider);
    return _RaceEngineerRequestScope(
      sessionId: sessionState.currentSession?.id.trim() ?? '',
      effectiveSessionId: _ref.read(backendSyncProvider).effectiveSessionId.trim(),
    );
  }

  bool _canApplyResponse(
    RaceEngineerAdviceResponse response,
    _RaceEngineerRequestScope requestScope,
  ) {
    final currentScope = _currentRequestScope();
    return currentScope.matches(requestScope) &&
        response.sessionId.trim() == currentScope.effectiveSessionId;
  }

  void _discardStaleResponse(_RaceEngineerRequestScope requestScope) {
    if (_activeRequestScope != null && _activeRequestScope!.matches(requestScope)) {
      _activeRequestScope = null;
    }
    if (mounted && state.status == RaceEngineerAdviceStatus.loading) {
      state = const RaceEngineerAdviceState.idle();
    }
  }
}

class RaceEngineerAdviceAutoPollController {
  final Ref _ref;
  Timer? _timer;
  DateTime? _pausedUntil;

  RaceEngineerAdviceAutoPollController(this._ref) {
    _ref.listen(sessionRecorderProvider, (_, __) => _syncTimer());
    _ref.listen(backendSyncProvider, (_, __) => _syncTimer());
    _ref.listen(backendV2EnabledProvider, (_, __) => _syncTimer());
    _ref.listen(raceEngineerAdviceProvider, (previous, next) {
      _handleAdviceState(previous, next);
    });
    _syncTimer();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  void _syncTimer() {
    final shouldPoll = _shouldAutoPoll();
    if (!shouldPoll) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer ??= Timer.periodic(
      _ref.read(raceEngineerAdviceAutoPollIntervalProvider),
      (_) => _tick(),
    );
  }

  void _tick() {
    if (!_shouldAutoPoll()) {
      _syncTimer();
      return;
    }

    final now = DateTime.now();
    if (_pausedUntil != null && _pausedUntil!.isAfter(now)) return;

    final state = _ref.read(raceEngineerAdviceProvider);
    if (state.status == RaceEngineerAdviceStatus.loading) return;
    if (state.isCooldownActive(now)) return;

    unawaited(_ref.read(raceEngineerAdviceProvider.notifier).requestAdvice());
  }

  void _handleAdviceState(
    RaceEngineerAdviceState? previous,
    RaceEngineerAdviceState next,
  ) {
    final now = DateTime.now();
    switch (next.status) {
      case RaceEngineerAdviceStatus.rateLimited:
        final cooldownExpiresAt = next.cooldownExpiresAt;
        if (cooldownExpiresAt != null) {
          _pausedUntil = cooldownExpiresAt;
        } else if (previous?.status != RaceEngineerAdviceStatus.rateLimited) {
          _pausedUntil = now.add(_ref.read(raceEngineerAdviceAutoPollBackoffProvider));
        }
        return;
      case RaceEngineerAdviceStatus.error:
        _pausedUntil = now.add(_ref.read(raceEngineerAdviceAutoPollBackoffProvider));
        return;
      case RaceEngineerAdviceStatus.success:
      case RaceEngineerAdviceStatus.noEvents:
        _pausedUntil = null;
        return;
      case RaceEngineerAdviceStatus.idle:
      case RaceEngineerAdviceStatus.loading:
        return;
    }
  }

  bool _shouldAutoPoll() {
    if (!_ref.read(backendV2EnabledProvider)) return false;

    final sessionState = _ref.read(sessionRecorderProvider);
    if (!sessionState.isRecording) return false;

    final syncState = _ref.read(backendSyncProvider);
    if (!syncState.enabled || !syncState.udpConnected) return false;

    final availability = _ref.read(raceEngineerAdviceAvailabilityProvider);
    if (!availability.canRequest) return false;

    return true;
  }
}

final raceEngineerAdviceAutoPollControllerProvider =
    Provider.autoDispose<Object?>((ref) {
      final controller = RaceEngineerAdviceAutoPollController(ref);
      ref.onDispose(controller.dispose);
      return controller;
    });

final raceEngineerAdviceProvider =
    StateNotifierProvider<RaceEngineerAdviceNotifier, RaceEngineerAdviceState>((
      ref,
    ) {
      return RaceEngineerAdviceNotifier(ref);
    });

final raceEngineerAdviceAvailabilityProvider =
    Provider<RaceEngineerAdviceAvailability>((ref) {
      final v2Enabled = ref.watch(backendV2EnabledProvider);
      if (!v2Enabled) {
        return const RaceEngineerAdviceAvailability.unavailable(
          'Race Engineer is available only when V2 data is enabled.',
        );
      }

      final sessionId = ref.watch(backendSyncProvider).effectiveSessionId;
      if (!_isEffectiveBackendSessionId(sessionId)) {
        return const RaceEngineerAdviceAvailability.unavailable(
          'Start a race to ask the engineer.',
        );
      }

      return const RaceEngineerAdviceAvailability.available();
    });

bool _isEffectiveBackendSessionId(String sessionId) {
  final trimmed = sessionId.trim();
  return trimmed.startsWith('session_') && trimmed.length > 'session_'.length;
}
