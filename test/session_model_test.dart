import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';

void main() {
  group('TelemetryPoint', () {
    test('constructor sets all required fields', () {
      final point = TelemetryPoint(
        timestamp: DateTime(2026),
        speedKmh: 120.5,
        rpm: 6500,
        gear: 4,
        throttle: 0.7,
        brake: 0.1,
      );

      expect(point.timestamp, DateTime(2026));
      expect(point.speedKmh, 120.5);
      expect(point.rpm, 6500);
      expect(point.gear, 4);
      expect(point.throttle, 0.7);
      expect(point.brake, 0.1);
    });

    test('toJson produces correct map', () {
      final point = TelemetryPoint(
        timestamp: DateTime(2026),
        packetId: 42,
        currentLap: 3,
        currentLapTime: const Duration(seconds: 30),
        speedKmh: 180.0,
        rpm: 7200,
        gear: 5,
        throttle: 0.9,
        brake: 0.0,
        clutch: 0.5,
        fuelCurrentL: 45.2,
        fuelCapacityL: 60.0,
        tireTemps: [85.0, 87.0, 86.0, 88.0],
        posX: 100.0,
        posY: 200.0,
        posZ: 50.0,
      );

      final json = point.toJson();

      expect(json['timestamp'], DateTime(2026).toIso8601String());
      expect(json['packet_id'], 42);
      expect(json['current_lap'], 3);
      expect(json['current_lap_time_ms'], 30000);
      expect(json['speed_kmh'], 180.0);
      expect(json['rpm'], 7200);
      expect(json['gear'], 5);
      expect(json['throttle'], 0.9);
      expect(json['brake'], 0.0);
      expect(json['clutch'], 0.5);
      expect(json['fuel_current_l'], 45.2);
      expect(json['fuel_capacity_l'], 60.0);
      expect(json['tire_temps'], [85.0, 87.0, 86.0, 88.0]);
      expect(json['pos_x'], 100.0);
      expect(json['pos_y'], 200.0);
      expect(json['pos_z'], 50.0);
    });

    test('toJson omits null fields', () {
      final point = TelemetryPoint(
        timestamp: DateTime(2026),
        speedKmh: 100.0,
        rpm: 5000,
        gear: 3,
        throttle: 0.5,
        brake: 0.2,
      );

      final json = point.toJson();

      expect(json['packet_id'], isNull);
      expect(json['current_lap'], isNull);
      expect(json['current_lap_time_ms'], isNull);
      expect(json['clutch'], isNull);
      expect(json['fuel_current_l'], isNull);
      expect(json['fuel_capacity_l'], isNull);
      expect(json['tire_temps'], isNull);
      expect(json['pos_x'], isNull);
      expect(json['pos_y'], isNull);
      expect(json['pos_z'], isNull);
    });
  });

  group('CompleteLap', () {
    group('isValidForEngineer', () {
      test('returns true for a normal lap with positive time and no flags', () {
        final lap = CompleteLap(
          id: 'lap1',
          lapNumber: 1,
          startTime: DateTime(2026),
          endTime: DateTime(2026).add(const Duration(seconds: 90)),
          officialLapTime: const Duration(seconds: 90),
        );

        expect(lap.isValidForEngineer, isTrue);
      });

      test('returns false for a lap with zero duration', () {
        final lap = CompleteLap(
          id: 'lap1',
          lapNumber: 1,
          startTime: DateTime(2026),
          endTime: DateTime(2026),
          officialLapTime: Duration.zero,
        );

        expect(lap.isValidForEngineer, isFalse);
      });

      test('returns false when isOutLap is true', () {
        final lap = CompleteLap(
          id: 'lap1',
          lapNumber: 1,
          startTime: DateTime(2026),
          endTime: DateTime(2026).add(const Duration(seconds: 90)),
          officialLapTime: const Duration(seconds: 90),
          isOutLap: true,
        );

        expect(lap.isValidForEngineer, isFalse);
      });

      test('returns false when isPitLap is true', () {
        final lap = CompleteLap(
          id: 'lap1',
          lapNumber: 1,
          startTime: DateTime(2026),
          endTime: DateTime(2026).add(const Duration(seconds: 90)),
          officialLapTime: const Duration(seconds: 90),
          isPitLap: true,
        );

        expect(lap.isValidForEngineer, isFalse);
      });

      test('returns true when isOutLap and isPitLap are null (assumed valid)', () {
        final lap = CompleteLap(
          id: 'lap1',
          lapNumber: 1,
          startTime: DateTime(2026),
          endTime: DateTime(2026).add(const Duration(seconds: 90)),
          officialLapTime: const Duration(seconds: 90),
          isOutLap: null,
          isPitLap: null,
        );

        expect(lap.isValidForEngineer, isTrue);
      });
    });

    test('toJson round-trip produces correct map', () {
      final lap = CompleteLap(
        id: 'lap-test-1',
        lapNumber: 2,
        startTime: DateTime(2026),
        endTime: DateTime(2026).add(const Duration(seconds: 95)),
        officialLapTime: const Duration(seconds: 95),
        bestLapTimeAtCompletion: const Duration(seconds: 93),
        position: 3,
        isOutLap: false,
        isPitLap: false,
        points: [
          TelemetryPoint(
            timestamp: DateTime(2026),
            speedKmh: 150.0,
            rpm: 6000,
            gear: 4,
            throttle: 0.8,
            brake: 0.0,
          ),
        ],
      );

      final json = lap.toJson();

      expect(json['id'], 'lap-test-1');
      expect(json['lap_number'], 2);
      expect(json['start_time'], DateTime(2026).toIso8601String());
      expect(
        json['end_time'],
        DateTime(2026)
            .add(const Duration(seconds: 95))
            .toIso8601String(),
      );
      expect(json['official_lap_time_ms'], 95000);
      expect(json['best_lap_time_at_completion_ms'], 93000);
      expect(json['position'], 3);
      expect(json['is_out_lap'], false);
      expect(json['is_pit_lap'], false);
      expect(json['points'], isA<List>());
      expect((json['points'] as List).length, 1);
    });
  });

  group('Session', () {
    test('duration returns correct value when endTime is set', () {
      final session = Session(
        id: 'session1',
        startTime: DateTime(2026),
        endTime: DateTime(2026).add(const Duration(minutes: 15)),
      );

      expect(session.duration, const Duration(minutes: 15));
    });

    test('duration returns null when endTime is null', () {
      final session = Session(
        id: 'session1',
        startTime: DateTime(2026),
      );

      expect(session.duration, isNull);
    });

    test('toJson round-trip produces correct map', () {
      final session = Session(
        id: 'session-test-1',
        startTime: DateTime(2026),
        endTime: DateTime(2026).add(const Duration(hours: 1)),
        game: 'GT7',
        ps5Ip: '192.168.1.100',
        points: [
          TelemetryPoint(
            timestamp: DateTime(2026),
            speedKmh: 120.0,
            rpm: 5000,
            gear: 3,
            throttle: 0.6,
            brake: 0.0,
          ),
        ],
        laps: [
          CompleteLap(
            id: 'lap1',
            lapNumber: 1,
            startTime: DateTime(2026),
            endTime: DateTime(2026).add(const Duration(seconds: 90)),
            officialLapTime: const Duration(seconds: 90),
          ),
        ],
      );

      final json = session.toJson();

      expect(json['id'], 'session-test-1');
      expect(json['start_time'], DateTime(2026).toIso8601String());
      expect(
        json['end_time'],
        DateTime(2026)
            .add(const Duration(hours: 1))
            .toIso8601String(),
      );
      expect(json['game'], 'GT7');
      expect(json['ps5_ip'], '192.168.1.100');
      expect(json['points'], isA<List>());
      expect(json['laps'], isA<List>());
      expect((json['points'] as List).length, 1);
      expect((json['laps'] as List).length, 1);
    });

    test('toJson includes trackName when set', () {
      final session = Session(
        id: 'session1',
        startTime: DateTime(2026),
        endTime: DateTime(2026).add(const Duration(hours: 1)),
        trackName: 'Nürburgring Nordschleife',
      );

      final json = session.toJson();

      expect(json['track_name'], 'Nürburgring Nordschleife');
    });

    test('toJson omits trackName when not set', () {
      final session = Session(
        id: 'session1',
        startTime: DateTime(2026),
      );

      final json = session.toJson();

      expect(json['track_name'], isNull);
    });
  });
}
