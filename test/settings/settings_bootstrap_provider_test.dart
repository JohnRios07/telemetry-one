import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/settings_bootstrap_dto.dart';
import 'package:telemetry_one/features/settings/providers/settings_bootstrap_provider.dart';

class _FakeSettingsClient extends BackendClient {
  int callCount = 0;
  SettingsBootstrapResponse? response;
  BackendRequestException? exception;
  Completer<SettingsBootstrapResponse>? completer;

  _FakeSettingsClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<SettingsBootstrapResponse> getSettingsBootstrap() async {
    callCount++;
    if (completer != null) {
      return completer!.future;
    }
    final error = exception;
    if (error != null) throw error;
    return response ??
        const SettingsBootstrapResponse(
          apiVersion: settingsBootstrapApiVersion,
          bootstrap: SettingsBootstrap(
            clientHints: SettingsBootstrapSection(values: {'alias': 'alex'}),
            limits: SettingsBootstrapSection(values: {'maxBatchFrames': 600}),
            capabilities: SettingsBootstrapSection(values: {'readOnly': true}),
          ),
        );
  }
}

ProviderContainer _container(_FakeSettingsClient client) {
  return ProviderContainer(
    overrides: [
      backendClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  group('settingsBootstrapProvider', () {
    test('returns bootstrap data from backend client', () async {
      final client = _FakeSettingsClient();
      final container = _container(client);
      addTearDown(container.dispose);

      final value = await container.read(settingsBootstrapProvider.future);

      expect(client.callCount, 1);
      expect(value.bootstrap.clientHints.values['alias'], 'alex');
      expect(value.bootstrap.limits.values['maxBatchFrames'], 600);
      expect(value.bootstrap.capabilities.values['readOnly'], isTrue);
    });

    test('surfaces backend errors', () async {
      final client = _FakeSettingsClient()
        ..exception = const BackendRequestException(
          statusCode: 0,
          error: BackendError(code: 'network_error', message: 'offline'),
        );
      final container = _container(client);
      addTearDown(container.dispose);

      try {
        await container.read(settingsBootstrapProvider.future);
        fail('Expected exception');
      } catch (e) {
        expect(e, isA<BackendRequestException>());
      }
    });

    test('supports loading with a pending future', () async {
      final client = _FakeSettingsClient()
        ..completer = Completer<SettingsBootstrapResponse>();
      final container = _container(client);
      addTearDown(container.dispose);

      final future = container.read(settingsBootstrapProvider.future);
      expect(client.callCount, 1);

      client.completer!.complete(
        const SettingsBootstrapResponse(
          apiVersion: settingsBootstrapApiVersion,
          bootstrap: SettingsBootstrap(
            clientHints: SettingsBootstrapSection(values: {'alias': 'alex'}),
            limits: SettingsBootstrapSection(values: {'maxBatchFrames': 600}),
            capabilities: SettingsBootstrapSection(values: {'readOnly': true}),
          ),
        ),
      );

      final value = await future;
      expect(value.bootstrap.clientHints.values['alias'], 'alex');
    });
  });
}
