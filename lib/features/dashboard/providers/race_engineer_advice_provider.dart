import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_client.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../../../../core/backend/v2_bridge_providers.dart';

enum RaceEngineerAdviceStatus {
  idle,
  loading,
  success,
  noEvents,
  rateLimited,
  error,
}

const Duration raceEngineerAdviceRequestTimeout = Duration(seconds: 25);

final raceEngineerAdviceRequestTimeoutProvider = Provider<Duration>((ref) {
  return raceEngineerAdviceRequestTimeout;
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

class RaceEngineerAdviceNotifier
    extends StateNotifier<RaceEngineerAdviceState> {
  final Ref _ref;
  Timer? _cooldownTimer;

  RaceEngineerAdviceNotifier(this._ref)
    : super(const RaceEngineerAdviceState.idle());

  Future<void> requestAdvice({
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  }) async {
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

    final sessionId = _ref.read(backendSyncProvider).effectiveSessionId.trim();
    state = const RaceEngineerAdviceState(
      status: RaceEngineerAdviceStatus.loading,
    );

    try {
      final timeout = _ref.read(raceEngineerAdviceRequestTimeoutProvider);
      final response = await _ref
          .read(backendClientProvider)
          .requestRaceEngineerAdvice(sessionId, request)
          .timeout(
            timeout,
            onTimeout: () {
              throw TimeoutException(
                'Race Engineer advice request timed out after '
                '${timeout.inSeconds} seconds.',
              );
            },
          );

      if (response.hasNoEvents) {
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
}

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
