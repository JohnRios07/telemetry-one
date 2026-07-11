import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';
import 'package:telemetry_one/core/network/connection_manager.dart';

void main() {
  group('TelemetryData', () {
    test('default values are zero', () {
      final data = TelemetryData(timestamp: DateTime.now());
      expect(data.speedKmh, 0);
      expect(data.rpm, 0);
      expect(data.gear, 0);
      expect(data.fuelPercent, 0);
    });

    test('rev limiter detection works', () {
      final data = TelemetryData(
        timestamp: DateTime.now(),
        rpm: 9000,
        rpmRevLimiter: 8500,
      );
      expect(data.isAtRevLimiter, true);
    });

    test('rpm ratio is clamped correctly', () {
      final data = TelemetryData(
        timestamp: DateTime.now(),
        rpm: 5000,
        rpmRevLimiter: 10000,
      );
      expect(data.rpmRatio, 0.5);
    });
  });

  group('ConnectionManager', () {
    test('validates IP addresses correctly', () {
      expect(ConnectionManager.isValidIp('192.168.1.100'), true);
      expect(ConnectionManager.isValidIp('0.0.0.0'), true);
      expect(ConnectionManager.isValidIp('256.1.1.1'), false);
      expect(ConnectionManager.isValidIp('not.an.ip'), false);
      expect(ConnectionManager.isValidIp(''), false);
    });
  });
}
