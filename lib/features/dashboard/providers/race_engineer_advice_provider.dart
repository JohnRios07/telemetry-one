import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_client.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../../../../core/backend/v2_bridge_providers.dart';

enum RaceEngineerAdviceStatus { idle, loading, success, noEvents, error }

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

    final v2Enabled = _ref.read(backendV2EnabledProvider);
    if (!v2Enabled) {
      state = const RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: 'Race Engineer is available only when V2 data is enabled.',
      );
      return;
    }

    final sessionId = _ref.read(backendSyncProvider).effectiveSessionId;
    if (sessionId.trim().isEmpty) {
      state = const RaceEngineerAdviceState(
        status: RaceEngineerAdviceStatus.error,
        message: 'No active backend session is available yet.',
      );
      return;
    }

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
