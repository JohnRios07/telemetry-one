// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/lap_alignment.dart';
import 'package:telemetry_one/features/engineer/domain/lap_comparison.dart';

void main() {
  final DateTime refDate = DateTime(2026);

  TelemetryPoint _point({
    required int index,
    double speedKmh = 100,
    double throttle = 0.5,
    double brake = 0,
    double? posX,
    double? posY = 0,
    double? posZ = 0,
    bool sameTimestamp = false,
  }) {
    return TelemetryPoint(
      timestamp: sameTimestamp ? refDate : refDate.add(Duration(seconds: index)),
      speedKmh: speedKmh,
      rpm: 5000,
      gear: 4,
      throttle: throttle,
      brake: brake,
      posX: posX,
      posY: posY,
      posZ: posZ,
    );
  }

  CompleteLap _lap({
    required String id,
    required int lapNumber,
    required int officialLapTimeMs,
    required List<TelemetryPoint> points,
    bool? isOutLap,
    bool? isPitLap,
  }) {
    final Duration lapTime = Duration(milliseconds: officialLapTimeMs);
    return CompleteLap(
      id: id,
      lapNumber: lapNumber,
      startTime: refDate,
      endTime: refDate.add(lapTime),
      officialLapTime: lapTime,
      points: points,
      isOutLap: isOutLap,
      isPitLap: isPitLap,
    );
  }

  Session _session(List<CompleteLap> laps) {
    return Session(
      id: 'session-1',
      startTime: refDate,
      endTime: refDate.add(const Duration(minutes: 30)),
      laps: laps,
    );
  }

  List<TelemetryPoint> _positionedPoints({
    int count = 11,
    double speedBase = 100,
    double speedStep = 1,
    double throttleBase = 0.4,
    double throttleStep = 0.01,
    double brakeBase = 0.05,
    double brakeStep = 0.005,
    bool sameTimestamp = false,
  }) {
    return List<TelemetryPoint>.generate(count, (int index) {
      return _point(
        index: index,
        speedKmh: speedBase + (speedStep * index),
        throttle: throttleBase + (throttleStep * index),
        brake: brakeBase + (brakeStep * index),
        posX: index.toDouble(),
        sameTimestamp: sameTimestamp,
      );
    }, growable: false);
  }

  List<TelemetryPoint> _indexOnlyPoints({
    int count = 10,
    double speedBase = 100,
    double throttleBase = 0.5,
    double brakeBase = 0.1,
  }) {
    return List<TelemetryPoint>.generate(count, (int index) {
      return _point(
        index: index,
        speedKmh: speedBase + index,
        throttle: throttleBase,
        brake: brakeBase,
      );
    }, growable: false);
  }

  group('LapAlignment.compareSessionLaps', () {
    test('aligns best and last laps when the session has two or more valid laps', () {
      final CompleteLap bestLap = _lap(
        id: 'lap-best',
        lapNumber: 1,
        officialLapTimeMs: 60000,
        points: _positionedPoints(),
      );
      final CompleteLap middleLap = _lap(
        id: 'lap-middle',
        lapNumber: 2,
        officialLapTimeMs: 62000,
        points: _positionedPoints(speedBase: 105),
      );
      final CompleteLap lastLap = _lap(
        id: 'lap-last',
        lapNumber: 3,
        officialLapTimeMs: 61000,
        points: _positionedPoints(
          speedBase: 110,
          throttleBase: 0.5,
          brakeBase: 0.1,
        ),
      );

      final LapComparisonResult result = LapAlignment.compareSessionLaps(
        _session([bestLap, middleLap, lastLap]),
      );

      expect(result.isAvailable, isTrue);
      expect(result.alignmentMode, ComparisonAlignmentMode.normalizedProgress);
      expect(result.confidence, ComparisonConfidence.medium);
      expect(result.coverageRatio, closeTo(1, 0.0001));
      expect(result.points, hasLength(100));
      expect(result.summary, isNotNull);
      expect(result.summary!.bestLap.id, 'lap-best');
      expect(result.summary!.lastLap.id, 'lap-last');
      expect(result.summary!.lapTimeDelta, const Duration(seconds: 1));
      expect(result.summary!.averageSpeedDeltaKmh, closeTo(10, 0.0001));
      expect(result.summary!.averageThrottleDelta, closeTo(0.1, 0.0001));
      expect(result.summary!.averageBrakeDelta, closeTo(0.05, 0.0001));
      expect(result.points.first.progress, closeTo(0, 0.0001));
      expect(result.points.last.progress, closeTo(1, 0.0001));
    });

    test('returns unavailable when the session has only one valid lap', () {
      final LapComparisonResult result = LapAlignment.compareSessionLaps(
        _session([
          _lap(
            id: 'lap-1',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _positionedPoints(),
          ),
        ]),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        'La sesión necesita al menos dos vueltas válidas.',
      );
      expect(result.alignmentMode, ComparisonAlignmentMode.unavailable);
    });

    test('returns unavailable when the session has no laps', () {
      final LapComparisonResult result = LapAlignment.compareSessionLaps(
        _session(const <CompleteLap>[]),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        'La sesión necesita al menos dos vueltas válidas.',
      );
      expect(result.points, isEmpty);
    });

    test('returns unavailable when the best lap and the last lap are the same lap', () {
      final LapComparisonResult result = LapAlignment.compareSessionLaps(
        _session([
          _lap(
            id: 'lap-1',
            lapNumber: 1,
            officialLapTimeMs: 61000,
            points: _positionedPoints(),
          ),
          _lap(
            id: 'lap-2',
            lapNumber: 2,
            officialLapTimeMs: 60000,
            points: _positionedPoints(speedBase: 105),
          ),
        ]),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        'La mejor vuelta y la última son la misma vuelta.',
      );
    });
  });

  group('LapAlignment.compare', () {
    test('falls back to point-index alignment when progress normalization cannot be computed', () {
      final LapComparisonResult result = LapAlignment.compare(
        sessionId: 'session-1',
        bestLap: _lap(
          id: 'lap-best',
          lapNumber: 1,
          officialLapTimeMs: 60000,
          points: _indexOnlyPoints(speedBase: 100, throttleBase: 0.4),
        ),
        lastLap: _lap(
          id: 'lap-last',
          lapNumber: 2,
          officialLapTimeMs: 60500,
          points: _indexOnlyPoints(speedBase: 103, throttleBase: 0.45),
        ),
        bucketCount: 10,
      );

      expect(result.isAvailable, isTrue);
      expect(result.alignmentMode, ComparisonAlignmentMode.pointIndexFallback);
      expect(result.confidence, ComparisonConfidence.low);
      expect(result.coverageRatio, closeTo(1, 0.0001));
      expect(result.points, hasLength(10));
    });

    test('uses normalized progress even when telemetry points share the same timestamps', () {
      final LapComparisonResult result = LapAlignment.compare(
        sessionId: 'session-1',
        bestLap: _lap(
          id: 'lap-best',
          lapNumber: 1,
          officialLapTimeMs: 60000,
          points: _positionedPoints(sameTimestamp: true),
        ),
        lastLap: _lap(
          id: 'lap-last',
          lapNumber: 2,
          officialLapTimeMs: 60800,
          points: _positionedPoints(speedBase: 108, sameTimestamp: true),
        ),
      );

      expect(result.isAvailable, isTrue);
      expect(result.alignmentMode, ComparisonAlignmentMode.normalizedProgress);
      expect(result.confidence, ComparisonConfidence.medium);
    });

    test('returns unavailable when either lap has fewer than two telemetry points', () {
      final LapComparisonResult result = LapAlignment.compare(
        sessionId: 'session-1',
        bestLap: _lap(
          id: 'lap-best',
          lapNumber: 1,
          officialLapTimeMs: 60000,
          points: [_point(index: 0, posX: 0)],
        ),
        lastLap: _lap(
          id: 'lap-last',
          lapNumber: 2,
          officialLapTimeMs: 61000,
          points: _positionedPoints(),
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        'Faltan puntos suficientes para comparar vueltas locales.',
      );
    });

    test('returns unavailable when comparable point coverage is too low', () {
      final LapComparisonResult result = LapAlignment.compare(
        sessionId: 'session-1',
        bestLap: _lap(
          id: 'lap-best',
          lapNumber: 1,
          officialLapTimeMs: 60000,
          points: [
            _point(index: 0, posX: 0),
            _point(index: 1, posX: 100),
          ],
        ),
        lastLap: _lap(
          id: 'lap-last',
          lapNumber: 2,
          officialLapTimeMs: 61000,
          points: [
            _point(index: 0, posX: 0, speedKmh: 110),
            _point(index: 1, posX: 100, speedKmh: 111),
          ],
        ),
      );

      expect(result.isAvailable, isFalse);
      expect(
        result.unavailableReason,
        'La cobertura de puntos comparables es demasiado baja.',
      );
    });
  });
}
