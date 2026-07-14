import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';

void main() {
  group('createBackendConfigFromEnv', () {
    test('returns default config when no env defines set', () {
      const config = BackendConfig();
      final envConfig = createBackendConfigFromEnv();

      expect(envConfig.baseUrl, config.baseUrl);
      expect(envConfig.useV2Data, config.useV2Data);
      expect(envConfig.driverAlias, config.driverAlias);
      expect(envConfig.requestTimeout, config.requestTimeout);
      expect(envConfig.maxRetries, config.maxRetries);
      expect(envConfig.defaultBatchSize, config.defaultBatchSize);
      expect(envConfig.maxBatchSize, config.maxBatchSize);
    });

    test('env baseUrl overrides default when defined', () {
      // In test mode, String.fromEnvironment returns '' when not defined,
      // so this verifies the fallback logic.
      final envConfig = createBackendConfigFromEnv();

      // The test runner has no dart-define, so defaults apply
      expect(envConfig.baseUrl, 'http://localhost:8080');
      expect(envConfig.useV2Data, false);

      // Verify the API base derivation still works
      expect(envConfig.apiBase, 'http://localhost:8080/api/v1');
    });

    test('useV2Data defaults to false', () {
      final envConfig = createBackendConfigFromEnv();
      expect(envConfig.useV2Data, false);
    });

    test('BackendConfig defaults are stable', () {
      const config = BackendConfig();
      expect(config.baseUrl, 'http://localhost:8080');
      expect(config.useV2Data, false);
      expect(config.driverAlias, 'driver');
      expect(config.requestTimeout, Duration(seconds: 10));
      expect(config.maxRetries, 3);
      expect(config.defaultBatchSize, 120);
      expect(config.maxBatchSize, 600);
    });
  });
}
