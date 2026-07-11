import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/session_analyzer.dart';
import 'package:telemetry_one/features/engineer/domain/session_summary.dart';

void main() {
  final refDate = DateTime(2026);

  TelemetryPoint _point({
    double speedKmh = 100,
    double rpm = 5000,
    int gear = 3,
    double throttle = 0,
    double brake = 0,
    double? fuelCurrentL,
    List<double>? tireTemps,
    DateTime? timestamp,
  }) {
    return TelemetryPoint(
      timestamp: timestamp ?? refDate,
      speedKmh: speedKmh,
      rpm: rpm,
      gear: gear,
      throttle: throttle,
      brake: brake,
      fuelCurrentL: fuelCurrentL,
      tireTemps: tireTemps,
    );
  }

  CompleteLap _lap({
    String id = 'lap-1',
    int lapNumber = 1,
    int officialLapTimeSeconds = 90,
    List<TelemetryPoint> points = const [],
    bool? isOutLap,
    bool? isPitLap,
  }) {
    final duration = Duration(seconds: officialLapTimeSeconds);
    return CompleteLap(
      id: id,
      lapNumber: lapNumber,
      startTime: refDate,
      endTime: refDate.add(duration),
      officialLapTime: duration,
      points: points,
      isOutLap: isOutLap,
      isPitLap: isPitLap,
    );
  }

  Session _session({
    String? trackName,
    List<CompleteLap> laps = const [],
  }) {
    return Session(
      id: 'session-1',
      startTime: refDate,
      endTime: refDate.add(const Duration(hours: 1)),
      trackName: trackName,
      laps: laps,
    );
  }

  group('validLaps', () {
    test('keeps valid laps', () {
      final session = _session(laps: [
        _lap(),
        _lap(id: 'lap-2', lapNumber: 2),
      ]);
      expect(SessionAnalyzer.validLaps(session), hasLength(2));
    });

    test('filters out zero-time laps', () {
      final session = _session(laps: [
        _lap(officialLapTimeSeconds: 0),
        _lap(id: 'lap-2', lapNumber: 2),
      ]);
      final result = SessionAnalyzer.validLaps(session);
      expect(result, hasLength(1));
      expect(result.single.id, 'lap-2');
    });

    test('filters out out-laps', () {
      final session = _session(laps: [
        _lap(isOutLap: true),
        _lap(id: 'lap-2', lapNumber: 2),
      ]);
      final result = SessionAnalyzer.validLaps(session);
      expect(result, hasLength(1));
      expect(result.single.id, 'lap-2');
    });

    test('filters out pit-laps', () {
      final session = _session(laps: [
        _lap(isPitLap: true),
        _lap(id: 'lap-2', lapNumber: 2),
      ]);
      final result = SessionAnalyzer.validLaps(session);
      expect(result, hasLength(1));
      expect(result.single.id, 'lap-2');
    });

    test('filters laps that combine invalid flags', () {
      final session = _session(laps: [
        _lap(officialLapTimeSeconds: 0, isOutLap: true, isPitLap: true),
      ]);
      expect(SessionAnalyzer.validLaps(session), isEmpty);
    });

    test('returns empty list when session has no laps', () {
      expect(SessionAnalyzer.validLaps(_session()), isEmpty);
    });
  });

  group('fuelUsedForLap', () {
    test('returns delta between first and last fuel reading', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: 10),
        _point(fuelCurrentL: 9.5),
        _point(fuelCurrentL: 8),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), closeTo(2.0, 0.001));
    });

    test('returns null when no fuel datapoints exist', () {
      final lap = _lap(points: [_point(), _point()]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), isNull);
    });

    test('returns null when delta is negative', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: 5),
        _point(fuelCurrentL: 10),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), isNull);
    });

    test('returns null when start fuel is NaN', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: double.nan),
        _point(fuelCurrentL: 10),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), isNull);
    });

    test('returns null when end fuel is NaN', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: 10),
        _point(fuelCurrentL: double.nan),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), isNull);
    });

    test('returns null when delta is infinite', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: double.infinity),
        _point(fuelCurrentL: 10),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), isNull);
    });

    test('returns null when points list is empty', () {
      expect(SessionAnalyzer.fuelUsedForLap(_lap()), isNull);
    });

    test('ignores points without fuel readings between first and last', () {
      final lap = _lap(points: [
        _point(fuelCurrentL: 12),
        _point(),
        _point(fuelCurrentL: 10),
        _point(),
        _point(fuelCurrentL: 7),
      ]);
      expect(SessionAnalyzer.fuelUsedForLap(lap), closeTo(5.0, 0.001));
    });
  });

  group('averageTireTemperature', () {
    test('averages all tire temperatures above zero', () {
      final lap = _lap(points: [
        _point(tireTemps: [80, 90, 85, 95]),
      ]);
      expect(SessionAnalyzer.averageTireTemperature(lap), closeTo(87.5, 0.001));
    });

    test('returns null when no tire data present', () {
      final lap = _lap(points: [_point(), _point()]);
      expect(SessionAnalyzer.averageTireTemperature(lap), isNull);
    });

    test('ignores zero temperatures', () {
      final lap = _lap(points: [
        _point(tireTemps: [80, 0, 90, 0]),
      ]);
      expect(SessionAnalyzer.averageTireTemperature(lap), closeTo(85.0, 0.001));
    });

    test('returns null when all tire temperatures are zero', () {
      final lap = _lap(points: [
        _point(tireTemps: [0, 0, 0]),
      ]);
      expect(SessionAnalyzer.averageTireTemperature(lap), isNull);
    });

    test('averages across multiple telemetry points', () {
      final lap = _lap(points: [
        _point(tireTemps: [80, 100]),
        _point(tireTemps: [90, 110]),
      ]);
      expect(SessionAnalyzer.averageTireTemperature(lap), closeTo(95.0, 0.001));
    });

    test('handles mixed null and non-null tire temps', () {
      final lap = _lap(points: [
        _point(tireTemps: null),
        _point(tireTemps: [70, 80]),
        _point(tireTemps: null),
      ]);
      expect(SessionAnalyzer.averageTireTemperature(lap), closeTo(75.0, 0.001));
    });

    test('returns null when points list is empty', () {
      expect(SessionAnalyzer.averageTireTemperature(_lap()), isNull);
    });
  });

  group('brakeThrottleOverlapRatio', () {
    test('returns 0 for empty points', () {
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(_lap()), 0);
    });

    test('returns 1.0 when all points have overlap', () {
      final lap = _lap(points: [
        _point(throttle: 0.8, brake: 0.5),
        _point(throttle: 1.0, brake: 0.3),
      ]);
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(lap), 1.0);
    });

    test('returns 0 when no points overlap', () {
      final lap = _lap(points: [
        _point(throttle: 0.8, brake: 0.0),
        _point(throttle: 0.0, brake: 0.5),
        _point(throttle: 0.1, brake: 0.1),
      ]);
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(lap), 0.0);
    });

    test('returns 0.5 for half overlap', () {
      final lap = _lap(points: [
        _point(throttle: 0.8, brake: 0.0),
        _point(throttle: 0.0, brake: 0.5),
        _point(throttle: 0.8, brake: 0.5),
        _point(throttle: 1.0, brake: 0.3),
      ]);
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(lap), 0.5);
    });

    test('uses 0.15 threshold for edge values', () {
      final lap = _lap(points: [
        _point(throttle: 0.15, brake: 0.15),
        _point(throttle: 0.14, brake: 0.15),
        _point(throttle: 0.15, brake: 0.14),
      ]);
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(lap), closeTo(1 / 3, 0.001));
    });

    test('returns 0 for single non-overlap point', () {
      final lap = _lap(points: [
        _point(throttle: 0.0, brake: 0.0),
      ]);
      expect(SessionAnalyzer.brakeThrottleOverlapRatio(lap), 0.0);
    });
  });

  group('buildListItem', () {
    test('includes trackName', () {
      final item = SessionAnalyzer.buildListItem(_session(trackName: 'Spa'));
      expect(item.trackName, 'Spa');
    });

    test('trackName is null when session has none', () {
      final item = SessionAnalyzer.buildListItem(_session());
      expect(item.trackName, isNull);
    });

    test('sets bestLap to null when no valid laps', () {
      final item = SessionAnalyzer.buildListItem(
        _session(laps: [
          _lap(isOutLap: true),
          _lap(id: 'lap-2', lapNumber: 2, isPitLap: true),
        ]),
      );
      expect(item.bestLap, isNull);
      expect(item.validLapCount, 0);
    });

    test('correct count and bestLap with valid laps', () {
      final item = SessionAnalyzer.buildListItem(
        _session(laps: [
          _lap(officialLapTimeSeconds: 92),
          _lap(id: 'lap-2', lapNumber: 2, officialLapTimeSeconds: 90),
          _lap(id: 'lap-3', lapNumber: 3, officialLapTimeSeconds: 95),
        ]),
      );
      expect(item.validLapCount, 3);
      expect(item.bestLap, const Duration(seconds: 90));
    });
  });

  group('buildSummary', () {
    test('metrics unavailable when no valid laps', () {
      final summary = SessionAnalyzer.buildSummary(
        _session(laps: [_lap(isOutLap: true)]),
      );
      expect(summary.validLapCount, 0);
      expect(summary.bestLap.isAvailable, isFalse);
      expect(summary.averageLap.isAvailable, isFalse);
      expect(summary.fuelPerLap.isAvailable, isFalse);
      expect(summary.consistency.isAvailable, isFalse);
      expect(summary.totalLaps.value, 0);
      expect(summary.lapRows, isEmpty);
    });

    test('consistency unavailable with single lap', () {
      final summary = SessionAnalyzer.buildSummary(_session(laps: [_lap()]));
      expect(summary.validLapCount, 1);
      expect(summary.consistency.isAvailable, isFalse);
      expect(summary.bestLap.value, const Duration(seconds: 90));
      expect(summary.averageLap.value, const Duration(seconds: 90));
      expect(summary.fuelPerLap.isAvailable, isFalse);
    });

    test('correct values for multi-lap', () {
      final lap1 = _lap(
        officialLapTimeSeconds: 90,
        points: [
          _point(fuelCurrentL: 10),
          _point(fuelCurrentL: 8),
        ],
      );
      final lap2 = _lap(
        id: 'lap-2',
        lapNumber: 2,
        officialLapTimeSeconds: 92,
        points: [
          _point(fuelCurrentL: 15),
          _point(fuelCurrentL: 5),
        ],
      );
      final summary = SessionAnalyzer.buildSummary(_session(laps: [lap1, lap2]));

      expect(summary.validLapCount, 2);
      expect(summary.totalLaps.value, 2);
      expect(summary.bestLap.value, const Duration(seconds: 90));
      expect(summary.averageLap.value, const Duration(milliseconds: 91000));
      expect(summary.fuelPerLap.value, closeTo(6.0, 0.001));
      expect(summary.consistency.value, closeTo(98.901, 0.01));

      expect(summary.lapRows, hasLength(2));
      expect(summary.lapRows[0].isBestLap, isTrue);
      expect(summary.lapRows[0].isLastLap, isFalse);
      expect(summary.lapRows[0].fuelUsedLiters, closeTo(2.0, 0.001));
      expect(summary.lapRows[1].isBestLap, isFalse);
      expect(summary.lapRows[1].isLastLap, isTrue);
      expect(summary.lapRows[1].fuelUsedLiters, closeTo(10.0, 0.001));
    });

    test('handles laps without fuel readings', () {
      final lap1 = _lap(officialLapTimeSeconds: 90);
      final lap2 = _lap(
        id: 'lap-2',
        lapNumber: 2,
        officialLapTimeSeconds: 92,
      );
      final summary = SessionAnalyzer.buildSummary(_session(laps: [lap1, lap2]));

      expect(summary.fuelPerLap.isAvailable, isFalse);
      expect(summary.lapRows[0].fuelUsedLiters, isNull);
      expect(summary.lapRows[1].fuelUsedLiters, isNull);
    });
  });
}
