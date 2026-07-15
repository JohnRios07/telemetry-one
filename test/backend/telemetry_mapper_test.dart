import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/telemetry_mapper.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';

void main() {
  group('mapTelemetryToFrame', () {
    final baseTime = DateTime.fromMillisecondsSinceEpoch(1720656000123);

    TelemetryData _data({
      int packetId = 1,
      double speedKmh = 210,
      double rpm = 7100,
      int gear = 4,
      double throttle = 0.82,
      double brake = 0,
      double steering = -0.12,
      double fuelL = 38.4,
      double posX = 123.4,
      double posY = 5.6,
      double posZ = 789.1,
      int currentLap = 2,
      int? currentLapTimeMs = 81234,
      int? lastLapMs = 91345,
      int? bestLapMs = 90210,
      bool isOnTrack = true,
    }) {
      return TelemetryData(
        timestamp: baseTime,
        packetId: packetId,
        speedKmh: speedKmh,
        rpm: rpm,
        gear: gear,
        throttle: throttle,
        brake: brake,
        steeringAngle: steering,
        isOnTrack: isOnTrack,
        fuelCurrentL: fuelL,
        posX: posX,
        posY: posY,
        posZ: posZ,
        currentLap: currentLap,
        currentLapTime:
            currentLapTimeMs != null
                ? Duration(milliseconds: currentLapTimeMs)
                : null,
        lastLapTime:
            lastLapMs != null ? Duration(milliseconds: lastLapMs) : null,
        bestLapTime:
            bestLapMs != null ? Duration(milliseconds: bestLapMs) : null,
      );
    }

    test('maps speedKmh to speedMps dividing by 3.6', () {
      final frame = mapTelemetryToFrame(_data(speedKmh: 210));
      expect(frame.speedMps, closeTo(58.33, 0.01));
    });

    test('maps timestamp to unix milliseconds', () {
      final frame = mapTelemetryToFrame(_data());
      expect(frame.timestampUnixMs, 1720656000123);
    });

    test('maps gear preserving -1 reverse, 0 neutral', () {
      final frame = mapTelemetryToFrame(_data(gear: -1));
      expect(frame.gear, -1);

      final frame2 = mapTelemetryToFrame(_data(gear: 0));
      expect(frame2.gear, 0);
    });

    test('maps throttle and brake normalized 0..1', () {
      final frame = mapTelemetryToFrame(_data(throttle: 0.82, brake: 0.15));
      expect(frame.throttle, 0.82);
      expect(frame.brake, 0.15);
    });

    test('maps currentLapTime to currentLapMs', () {
      final frame = mapTelemetryToFrame(_data(currentLapTimeMs: 81234));
      expect(frame.currentLapMs, 81234);
    });

    test('maps currentLapTime null to 0', () {
      final frame = mapTelemetryToFrame(_data(currentLapTimeMs: null));
      expect(frame.currentLapMs, 0);
    });

    test('includes lastLapMs and bestLapMs when present', () {
      final frame = mapTelemetryToFrame(
        _data(lastLapMs: 91345, bestLapMs: 90210),
      );

      final json = frame.toJson();
      expect(json['lastLapMs'], 91345);
      expect(json['bestLapMs'], 90210);
    });

    test('omits lastLapMs and bestLapMs when null', () {
      final frame = mapTelemetryToFrame(
        _data(lastLapMs: null, bestLapMs: null),
      );

      final json = frame.toJson();
      expect(json.containsKey('lastLapMs'), false);
      expect(json.containsKey('bestLapMs'), false);
    });

    test('omits optional yaw and wheel speed fields', () {
      final frame = mapTelemetryToFrame(_data());

      expect(frame.yawRadians, isNull);
      expect(frame.yawRate, isNull);
      expect(frame.wheelSpeedFL, isNull);
      expect(frame.wheelSpeedFR, isNull);
      expect(frame.wheelSpeedRL, isNull);
      expect(frame.wheelSpeedRR, isNull);

      final json = frame.toJson();
      expect(json.containsKey('yawRadians'), false);
      expect(json.containsKey('yawRate'), false);
      expect(json.containsKey('wheelSpeedFL'), false);
      expect(json.containsKey('wheelSpeedFR'), false);
      expect(json.containsKey('wheelSpeedRL'), false);
      expect(json.containsKey('wheelSpeedRR'), false);
    });

    test('maps fuelLiters from fuelCurrentL', () {
      final frame = mapTelemetryToFrame(_data(fuelL: 38.4));
      expect(frame.fuelLiters, 38.4);
    });

    test('maps position fields', () {
      final frame = mapTelemetryToFrame(
        _data(posX: 123.4, posY: 5.6, posZ: 789.1),
      );
      expect(frame.positionX, 123.4);
      expect(frame.positionY, 5.6);
      expect(frame.positionZ, 789.1);
    });

    test('maps steeringAngle', () {
      final frame = mapTelemetryToFrame(_data(steering: -0.12));
      expect(frame.steeringAngle, -0.12);
    });

    test('maps isOnTrack true when source is on track', () {
      final frame = mapTelemetryToFrame(_data(isOnTrack: true));
      expect(frame.isOnTrack, isTrue);
    });

    test('maps isOnTrack false when source is off track', () {
      final frame = mapTelemetryToFrame(_data(isOnTrack: false));
      expect(frame.isOnTrack, isFalse);
    });

    test('maps isOnTrack defaults to true in TelemetryData', () {
      final data = TelemetryData(timestamp: DateTime.now());
      expect(data.isOnTrack, isTrue);
    });

    test('maps lapNumber from currentLap', () {
      final frame = mapTelemetryToFrame(_data(currentLap: 3));
      expect(frame.lapNumber, 3);
    });

    test('batch request shape matches contract', () {
      final data1 = _data(packetId: 1, speedKmh: 200);
      final data2 = _data(packetId: 2, speedKmh: 210);

      final batch = buildBatchRequest('session_test_1', [data1, data2]);
      final json = batch.toJson();

      expect(json['sessionId'], 'session_test_1');
      expect(json['frames'], isA<List>());
      expect((json['frames'] as List).length, 2);

      final first = (json['frames'] as List)[0] as Map<String, dynamic>;
      expect(first['timestampUnixMs'], 1720656000123);
      expect(first['gear'], 4);
      expect(first['throttle'], 0.82);
      expect(first.containsKey('lastLapMs'), true);
    });

    test('batch omits optional frame fields that are null', () {
      final data = _data(lastLapMs: null, bestLapMs: null);
      final batch = buildBatchRequest('session_test_1', [data]);
      final json = batch.toJson();
      final frame = (json['frames'] as List)[0] as Map<String, dynamic>;

      expect(frame.containsKey('lastLapMs'), false);
      expect(frame.containsKey('bestLapMs'), false);
      expect(frame.containsKey('yawRadians'), false);
    });
  });

  group('computeBatchSize', () {
    test('returns 0 when no frames available', () {
      expect(computeBatchSize(availableFrames: 0), 0);
    });

    test('returns default batch when frames exceed default', () {
      expect(computeBatchSize(availableFrames: 500), 120);
    });

    test('returns available frames when below default', () {
      expect(computeBatchSize(availableFrames: 50), 50);
    });

    test('respects max batch limit as absolute cap', () {
      expect(
        computeBatchSize(availableFrames: 1000, defaultBatch: 600),
        600,
      );
    });

    test('maxBatch caps defaultBatch when smaller', () {
      expect(
        computeBatchSize(
          availableFrames: 1000,
          defaultBatch: 600,
          maxBatch: 300,
        ),
        300,
      );
    });

    test('available frames capped by both defaultBatch and maxBatch', () {
      expect(
        computeBatchSize(availableFrames: 500, defaultBatch: 120, maxBatch: 600),
        120,
      );
    });

    test('maxBatch alone limits when defaultBatch not supplied', () {
      expect(
        computeBatchSize(availableFrames: 500, defaultBatch: 120, maxBatch: 50),
        50,
      );
    });
  });
}
