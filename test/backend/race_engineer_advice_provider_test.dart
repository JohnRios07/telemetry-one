import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/features/dashboard/providers/race_engineer_advice_provider.dart';

class _FakeBackendClient extends BackendClient {
  int callCount = 0;
  String? lastSessionId;
  RaceEngineerAdviceResponse? response;
  BackendRequestException? exception;

  _FakeBackendClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<RaceEngineerAdviceResponse> requestRaceEngineerAdvice(
    String sessionId, [
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  ]) async {
    callCount++;
    lastSessionId = sessionId;
    final exception = this.exception;
    if (exception != null) throw exception;
    return response ??
        const RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'success',
          message: 'Brake earlier into turn 1.',
        );
  }
}

class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state)
    : super(config: const BackendConfig()) {
    this.state = state;
  }

  @override
  void dispose() {}
}

ProviderContainer _container({
  required BackendConfig config,
  required BackendSyncState syncState,
  required _FakeBackendClient client,
}) {
  return ProviderContainer(
    overrides: [
      backendConfigProvider.overrideWithValue(config),
      backendClientProvider.overrideWithValue(client),
      backendSyncProvider.overrideWith((ref) => _MockSyncNotifier(syncState)),
    ],
  );
}

void main() {
  group('RaceEngineerAdviceNotifier', () {
    test('starts idle and makes no backend call', () {
      final client = _FakeBackendClient();
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'local_test'),
        client: client,
      );
      addTearDown(container.dispose);

      final state = container.read(raceEngineerAdviceProvider);

      expect(state.status, RaceEngineerAdviceStatus.idle);
      expect(client.callCount, 0);
    });

    test('manual request uses effective session id and maps success', () async {
      final client = _FakeBackendClient();
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(
          sessionId: 'local_ignore',
          backendSessionId: 'session_abc123',
        ),
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 1);
      expect(client.lastSessionId, 'session_abc123');
      expect(state.status, RaceEngineerAdviceStatus.success);
      expect(state.message, 'Brake earlier into turn 1.');
    });

    test('maps no_events response without failure', () async {
      final client = _FakeBackendClient()
        ..response = const RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'no_events',
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      expect(
        container.read(raceEngineerAdviceProvider).status,
        RaceEngineerAdviceStatus.noEvents,
      );
    });

    test('maps backend failure to error and allows manual retry', () async {
      final client = _FakeBackendClient()
        ..exception = const BackendRequestException(
          statusCode: 500,
          error: BackendError(code: 'internal_error', message: 'boom'),
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();
      client.exception = null;
      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 2);
      expect(state.status, RaceEngineerAdviceStatus.success);
    });

    test('V2 disabled blocks backend call', () async {
      final client = _FakeBackendClient();
      final container = _container(
        config: const BackendConfig(useV2Data: false),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 0);
      expect(state.status, RaceEngineerAdviceStatus.error);
    });

    test('local fallback session id blocks backend call', () async {
      final client = _FakeBackendClient();
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'local_test_1'),
        client: client,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 0);
      expect(state.status, RaceEngineerAdviceStatus.error);
      expect(state.message, 'Start a race to ask the engineer.');
    });

    test('availability is unavailable until effective session_* exists', () {
      final client = _FakeBackendClient();
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'local_test_1'),
        client: client,
      );
      addTearDown(container.dispose);

      final availability = container.read(
        raceEngineerAdviceAvailabilityProvider,
      );

      expect(availability.canRequest, isFalse);
      expect(availability.message, 'Start a race to ask the engineer.');
    });
  });
}
