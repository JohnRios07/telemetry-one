import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';

void main() {
  group('TelemetryFrameDto.toJson', () {
    TelemetryFrameDto _baseFrame() {
      return const TelemetryFrameDto(
        timestampUnixMs: 1720656000123,
        speedMps: 58.33,
        rpm: 7100,
        gear: 4,
        throttle: 0.82,
        brake: 0.0,
        steeringAngle: -0.12,
        fuelLiters: 38.4,
        positionX: 123.4,
        positionY: 5.6,
        positionZ: 789.1,
        lapNumber: 2,
        currentLapMs: 81234,
        lastLapMs: 91345,
        bestLapMs: 90210,
        isOnTrack: true,
      );
    }

    test('uses steering key (not steeringAngle) matching backend contract', () {
      final json = _baseFrame().toJson();

      expect(json.containsKey('steering'), isTrue);
      expect(json.containsKey('steeringAngle'), isFalse);
      expect(json['steering'], -0.12);
    });

    test('steering key has correct value', () {
      final frame = _baseFrame();
      expect(frame.steeringAngle, -0.12);

      final json = frame.toJson();
      expect(json['steering'], frame.steeringAngle);
    });

    test('steeringAngle field exists in class but NOT in JSON output', () {
      final frame = _baseFrame();
      expect(frame.steeringAngle, -0.12);

      final json = frame.toJson();
      expect(json.keys.contains('steeringAngle'), isFalse,
          reason: 'backend DisallowUnknownFields rejects steeringAngle key');
      expect(json['steering'], -0.12);
    });

    test('all required keys present in JSON output', () {
      final json = _baseFrame().toJson();

      final required = [
        'timestampUnixMs',
        'speedMps',
        'rpm',
        'gear',
        'throttle',
        'brake',
        'steering',
        'fuelLiters',
        'positionX',
        'positionY',
        'positionZ',
        'lapNumber',
        'currentLapMs',
        'isOnTrack',
      ];
      for (final key in required) {
        expect(json.containsKey(key), isTrue,
            reason: 'Required key $key missing from toJson()');
      }
    });

    test('optional fields omitted when null', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1720656000123,
        speedMps: 58.33,
        rpm: 7100,
        gear: 4,
        throttle: 0.82,
        brake: 0.0,
        steeringAngle: -0.12,
        fuelLiters: 38.4,
        positionX: 123.4,
        positionY: 5.6,
        positionZ: 789.1,
        lapNumber: 2,
        currentLapMs: 81234,
        isOnTrack: true,
      );

      final json = frame.toJson();
      expect(json.containsKey('lastLapMs'), isFalse);
      expect(json.containsKey('bestLapMs'), isFalse);
      expect(json.containsKey('yawRadians'), isFalse);
      expect(json.containsKey('yawRate'), isFalse);
      expect(json.containsKey('wheelSpeedFL'), isFalse);
    });

    test('no unknown keys that backend might reject', () {
      final json = _baseFrame().toJson();

      final knownKeys = {
        'timestampUnixMs',
        'speedMps',
        'rpm',
        'gear',
        'throttle',
        'brake',
        'steering',
        'fuelLiters',
        'positionX',
        'positionY',
        'positionZ',
        'lapNumber',
        'currentLapMs',
        'isOnTrack',
        'lastLapMs',
        'bestLapMs',
        'yawRadians',
        'yawRate',
        'wheelSpeedFL',
        'wheelSpeedFR',
        'wheelSpeedRL',
        'wheelSpeedRR',
      };

      for (final key in json.keys) {
        expect(knownKeys.contains(key), isTrue,
            reason: 'Unknown key $key in toJson() — '
                'backend DisallowUnknownFields would reject');
      }
    });
  });

  group('FrameBatchRequest.toJson', () {
    test('includes steering in frame JSON within batch', () {
      final frame = TelemetryFrameDto(
        timestampUnixMs: 1,
        speedMps: 10,
        rpm: 2000,
        gear: 2,
        throttle: 0.5,
        brake: 0.0,
        steeringAngle: -0.05,
        fuelLiters: 50,
        positionX: 0,
        positionY: 0,
        positionZ: 0,
        lapNumber: 1,
        currentLapMs: 30000,
        isOnTrack: true,
      );

      final batch = FrameBatchRequest(
        sessionId: 'session_test',
        frames: [frame],
      );
      final json = batch.toJson();
      final frameJson = (json['frames'] as List)[0] as Map<String, dynamic>;

      expect(frameJson.containsKey('steering'), isTrue);
      expect(frameJson.containsKey('steeringAngle'), isFalse);
      expect(frameJson['steering'], -0.05);
    });
  });
}
