import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_client.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../../../../core/backend/v2_bridge_providers.dart';

enum RaceEngineerAdviceStatus { idle, loading, success, noEvents, error }

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

  const RaceEngineerAdviceState({
    this.status = RaceEngineerAdviceStatus.idle,
    this.response,
    this.message,
  });

  const RaceEngineerAdviceState.idle() : this();

  RaceEngineerAdviceState copyWith({
    RaceEngineerAdviceStatus? status,
    RaceEngineerAdviceResponse? response,
    String? message,
  }) {
    return RaceEngineerAdviceState(
      status: status ?? this.status,
      response: response ?? this.response,
      message: message ?? this.message,
    );
  }
}

class RaceEngineerAdviceNotifier
    extends StateNotifier<RaceEngineerAdviceState> {
  final Ref _ref;

  RaceEngineerAdviceNotifier(this._ref)
    : super(const RaceEngineerAdviceState.idle());

  Future<void> requestAdvice({
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  }) async {
    if (state.status == RaceEngineerAdviceStatus.loading) return;

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
      final response = await _ref
          .read(backendClientProvider)
          .requestRaceEngineerAdvice(sessionId, request);

      if (response.hasNoEvents) {
        state = RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.noEvents,
          response: response,
          message: response.advice,
        );
        return;
      }

      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.success,
        response: response,
        message: response.advice,
      );
    } on BackendRequestException catch (e) {
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: e.error.message,
      );
    } on Exception catch (e) {
      state = RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: e.toString(),
      );
    }
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
