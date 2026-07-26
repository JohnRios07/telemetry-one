import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/features/dashboard/providers/race_engineer_advice_provider.dart';
import 'package:telemetry_one/features/dashboard/providers/session_provider.dart';
import 'package:telemetry_one/core/storage/session_model.dart';

class _FakeBackendClient extends BackendClient {
  int callCount = 0;
  String? lastSessionId;
  RaceEngineerAdviceRequest? lastRequest;
  RaceEngineerAdviceResponse? response;
  BackendRequestException? exception;
  Object? thrown;
  Completer<RaceEngineerAdviceResponse>? pendingResponse;

  _FakeBackendClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<RaceEngineerAdviceResponse> requestRaceEngineerAdvice(
    String sessionId, [
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  ]) async {
    callCount++;
    lastSessionId = sessionId;
    lastRequest = request;
    final exception = this.exception;
    if (exception != null) throw exception;
    final thrown = this.thrown;
    if (thrown != null) throw thrown;
    final pendingResponse = this.pendingResponse;
    if (pendingResponse != null) return pendingResponse.future;
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

class _MockSessionRecorder extends SessionRecorder {
  _MockSessionRecorder(SessionState state) : super() {
    this.state = state;
  }

  @override
  void dispose() {}
}

class _AutoPollFakeNotifier extends RaceEngineerAdviceNotifier {
  int requestCount = 0;

  _AutoPollFakeNotifier(super.ref);

  @override
  Future<void> requestAdvice({
    RaceEngineerAdviceRequest request = const RaceEngineerAdviceRequest(),
  }) async {
    requestCount++;
    state = const RaceEngineerAdviceState(
      status: RaceEngineerAdviceStatus.loading,
    );
  }
}

ProviderContainer _container({
  required BackendConfig config,
  required BackendSyncState syncState,
  required _FakeBackendClient client,
  required Duration adviceTimeout,
}) {
  return ProviderContainer(
    overrides: [
      backendConfigProvider.overrideWithValue(config),
      backendClientProvider.overrideWithValue(client),
      backendSyncProvider.overrideWith((ref) => _MockSyncNotifier(syncState)),
      raceEngineerAdviceRequestTimeoutProvider.overrideWithValue(
        adviceTimeout,
      ),
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 1);
      expect(client.lastSessionId, 'session_abc123');
      expect(state.status, RaceEngineerAdviceStatus.success);
      expect(state.message, 'Brake earlier into turn 1.');
    });

    test('uses sinceUnixMs from the previous successful response window', () async {
      final client = _FakeBackendClient()
        ..response = const RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'success',
          message: 'Brake earlier into turn 1.',
          window: RaceEngineerAdviceWindow(untilUnixMs: 1720656012345),
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(
          sessionId: 'local_ignore',
          backendSessionId: 'session_abc123',
        ),
        client: client,
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();
      client.response = const RaceEngineerAdviceResponse(
        sessionId: 'session_test_1',
        status: 'success',
        message: 'Turn in later.',
      );

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      expect(client.callCount, 2);
      expect(client.lastRequest?.sinceUnixMs, 1720656012345);
    });

    test('maps rate_limited response to rateLimited status', () async {
      final client = _FakeBackendClient()
        ..response = const RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'rate_limited',
          message: 'Fallback: Brake earlier.',
          providerInfo: RaceEngineerProviderInfo(
            providerName: 'google-vertex-ai',
            model: 'gemini-2.0-pro',
            retryAfterSeconds: 17,
          ),
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(state.status, RaceEngineerAdviceStatus.rateLimited);
      expect(state.message, 'Fallback: Brake earlier.');
      expect(state.response?.providerInfo?.retryAfterSeconds, 17);
      expect(state.response?.providerInfo?.providerName, 'google-vertex-ai');
      expect(state.cooldownExpiresAt, isNotNull);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      expect(client.callCount, 1);
    });

    test(
      'auto-poll resumes after cooldown expiry without extending backoff',
      () async {
        late _AutoPollFakeNotifier notifier;
        final container = ProviderContainer(
          overrides: [
            backendConfigProvider.overrideWithValue(
              const BackendConfig(useV2Data: true),
            ),
            backendSyncProvider.overrideWith(
              (ref) => _MockSyncNotifier(
                const BackendSyncState(
                  sessionId: 'local_1',
                  status: SyncStatus.idle,
                  backendSessionId: 'session_test_1',
                  udpConnected: true,
                ),
              ),
            ),
            sessionRecorderProvider.overrideWith(
              (ref) => _MockSessionRecorder(
                SessionState(
                  status: RecordingStatus.recording,
                  currentSession: Session(
                    id: 'local_1',
                    startTime: DateTime.fromMillisecondsSinceEpoch(
                      1720656000000,
                    ),
                    game: 'GT7',
                  ),
                ),
              ),
            ),
            raceEngineerAdviceProvider.overrideWith((ref) {
              notifier = _AutoPollFakeNotifier(ref);
              return notifier;
            }),
            raceEngineerAdviceAutoPollIntervalProvider.overrideWithValue(
              const Duration(milliseconds: 60),
            ),
            raceEngineerAdviceAutoPollBackoffProvider.overrideWithValue(
              const Duration(milliseconds: 80),
            ),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          raceEngineerAdviceAutoPollControllerProvider,
          (_, __) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        notifier.state = RaceEngineerAdviceState(
          status: RaceEngineerAdviceStatus.rateLimited,
          response: const RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'rate_limited',
            providerInfo: RaceEngineerProviderInfo(retryAfterSeconds: 20),
          ),
          cooldownExpiresAt: DateTime.now().add(const Duration(milliseconds: 20)),
        );

        await Future<void>.delayed(const Duration(milliseconds: 30));
        notifier.state = notifier.state.copyWith(cooldownExpiresAt: null);

        await Future<void>.delayed(const Duration(milliseconds: 70));

        expect(notifier.requestCount, 1);
      },
    );

    test('maps rate_limited response without fallback message', () async {
      final client = _FakeBackendClient()
        ..response = const RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'rate_limited',
          providerInfo: RaceEngineerProviderInfo(retryAfterSeconds: 30),
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(state.status, RaceEngineerAdviceStatus.rateLimited);
      expect(state.message, isNull);
      expect(state.response?.providerInfo?.retryAfterSeconds, 30);
      expect(state.cooldownExpiresAt, isNotNull);
    });

    test(
      'rate_limited response without retryAfterSeconds does not block retry',
      () async {
        final client = _FakeBackendClient()
          ..response = const RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'provider_error',
            providerInfo: RaceEngineerProviderInfo(
              finishReason: 'rate_limited',
            ),
          );
        final container = _container(
          config: const BackendConfig(useV2Data: true),
          syncState: const BackendSyncState(sessionId: 'session_test_1'),
          client: client,
          adviceTimeout: raceEngineerAdviceRequestTimeout,
        );
        addTearDown(container.dispose);

        await container
            .read(raceEngineerAdviceProvider.notifier)
            .requestAdvice();
        await container
            .read(raceEngineerAdviceProvider.notifier)
            .requestAdvice();

        final state = container.read(raceEngineerAdviceProvider);
        expect(client.callCount, 2);
        expect(state.status, RaceEngineerAdviceStatus.rateLimited);
        expect(state.cooldownExpiresAt, isNull);
      },
    );

    test(
      'maps provider finishReason rate_limited to rateLimited status',
      () async {
        final client = _FakeBackendClient()
          ..response = const RaceEngineerAdviceResponse(
            sessionId: 'session_test_1',
            status: 'provider_error',
            message: 'Fallback: Turn in later.',
            providerInfo: RaceEngineerProviderInfo(
              finishReason: 'rate_limited',
              providerName: 'OpenRouter',
            ),
          );
        final container = _container(
          config: const BackendConfig(useV2Data: true),
          syncState: const BackendSyncState(sessionId: 'session_test_1'),
          client: client,
          adviceTimeout: raceEngineerAdviceRequestTimeout,
        );
        addTearDown(container.dispose);

        await container
            .read(raceEngineerAdviceProvider.notifier)
            .requestAdvice();

        final state = container.read(raceEngineerAdviceProvider);
        expect(state.status, RaceEngineerAdviceStatus.rateLimited);
        expect(state.message, 'Fallback: Turn in later.');
        expect(state.response?.providerInfo?.finishReason, 'rate_limited');
      },
    );

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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
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
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      final availability = container.read(
        raceEngineerAdviceAvailabilityProvider,
      );

      expect(availability.canRequest, isFalse);
      expect(availability.message, 'Start a race to ask the engineer.');
    });

    test('hung request times out and transitions to error', () async {
      final client = _FakeBackendClient()
        ..pendingResponse = Completer<RaceEngineerAdviceResponse>();
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
        adviceTimeout: const Duration(milliseconds: 1),
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 1);
      expect(state.status, RaceEngineerAdviceStatus.error);
      expect(state.message, contains('timed out'));
    });

    test('unknown failure transitions to error instead of loading', () async {
      final client = _FakeBackendClient()
        ..thrown = StateError('parser exploded');
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(client.callCount, 1);
      expect(state.status, RaceEngineerAdviceStatus.error);
      expect(state.message, 'Unexpected error while requesting Race Engineer advice.');
    });

    test('success response with real-shaped payload stays successful', () async {
      final signalPayload = <String, dynamic>{
        'kind': 'off_track_stint_warning',
        'severity': 'warning',
        'summary': 'You spent 2 laps off track.',
      };
      final client = _FakeBackendClient()
        ..response = RaceEngineerAdviceResponse(
          sessionId: 'session_test_1',
          status: 'success',
          message: '''
### Lap 4

Brake later into turn 1.

- Release the brake more smoothly.
- Commit to throttle earlier on exit.
''',
          signals: [
            RaceEngineerSignal(
              type: signalPayload['kind'] as String,
              severity: signalPayload['severity'] as String,
              summary: signalPayload['summary'] as String,
            ),
          ],
          providerInfo: const RaceEngineerProviderInfo(
            providerName: 'google-vertex-ai',
            model: 'gemini-2.0-pro',
            retryAfterSeconds: 17,
          ),
        );
      final container = _container(
        config: const BackendConfig(useV2Data: true),
        syncState: const BackendSyncState(sessionId: 'session_test_1'),
        client: client,
        adviceTimeout: raceEngineerAdviceRequestTimeout,
      );
      addTearDown(container.dispose);

      await container.read(raceEngineerAdviceProvider.notifier).requestAdvice();

      final state = container.read(raceEngineerAdviceProvider);
      expect(state.status, RaceEngineerAdviceStatus.success);
      expect(state.message, contains('### Lap 4'));
      expect(state.message, contains('Brake later into turn 1.'));
      expect(state.response?.providerInfo?.providerName, 'google-vertex-ai');
      expect(state.response?.providerInfo?.retryAfterSeconds, 17);
      expect(state.response?.signals, isNotEmpty);
    });
  });
}
