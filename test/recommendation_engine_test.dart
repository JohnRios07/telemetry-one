// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/recommendation_engine.dart';
import 'package:telemetry_one/features/engineer/domain/session_summary.dart';

void main() {
  final DateTime refDate = DateTime(2026);

  TelemetryPoint _point({
    required int index,
    double speedKmh = 100,
    double throttle = 0,
    double brake = 0,
    double? fuelCurrentL,
    List<double>? tireTemps,
    double? posX,
  }) {
    return TelemetryPoint(
      timestamp: refDate.add(Duration(seconds: index)),
      speedKmh: speedKmh,
      rpm: 5000,
      gear: 4,
      throttle: throttle,
      brake: brake,
      fuelCurrentL: fuelCurrentL,
      tireTemps: tireTemps,
      posX: posX,
      posY: 0,
      posZ: 0,
    );
  }

  List<TelemetryPoint> _comparisonPoints({
    int count = 11,
    double speedBase = 100,
    double throttle = 0,
    double brake = 0,
    int? overlapCount,
    double? startFuel,
    double? endFuel,
    List<double>? tireTemps,
  }) {
    return List<TelemetryPoint>.generate(count, (int index) {
      final double? fuelCurrentL;
      if (startFuel != null && endFuel != null) {
        final double ratio = count == 1 ? 0 : index / (count - 1);
        fuelCurrentL = startFuel - ((startFuel - endFuel) * ratio);
      } else {
        fuelCurrentL = null;
      }

      final bool overlapping = overlapCount != null && index < overlapCount;

      return _point(
        index: index,
        speedKmh: speedBase + index,
        throttle: overlapping ? 0.7 : throttle,
        brake: overlapping ? 0.7 : brake,
        fuelCurrentL: fuelCurrentL,
        tireTemps: tireTemps,
        posX: index.toDouble(),
      );
    }, growable: false);
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

  List<String> _titles(List<EngineerRecommendation> recommendations) {
    return recommendations.map((EngineerRecommendation item) => item.title).toList(
      growable: false,
    );
  }

  group('RecommendationEngine.build', () {
    test('returns empty recommendations when the session has no valid laps', () {
      final List<EngineerRecommendation> recommendations =
          RecommendationEngine.build(_session(const <CompleteLap>[]));

      expect(recommendations, isEmpty);
    });

    test('caps the result at four recommendations in the configured priority order', () {
      final List<EngineerRecommendation> recommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'lap-best',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(
              speedBase: 100,
              throttle: 0,
              brake: 0,
              overlapCount: 2,
              startFuel: 10,
              endFuel: 9,
              tireTemps: const [80, 80, 80, 80],
            ),
          ),
          _lap(
            id: 'lap-middle',
            lapNumber: 2,
            officialLapTimeMs: 90000,
            points: _comparisonPoints(
              speedBase: 95,
              throttle: 0,
              brake: 0,
              overlapCount: 2,
              startFuel: 10,
              endFuel: 9,
              tireTemps: const [81, 81, 81, 81],
            ),
          ),
          _lap(
            id: 'lap-last',
            lapNumber: 3,
            officialLapTimeMs: 62000,
            points: _comparisonPoints(
              speedBase: 110,
              throttle: 0,
              brake: 0,
              overlapCount: 8,
              startFuel: 10,
              endFuel: 8.7,
              tireTemps: const [84, 84, 84, 84],
            ),
          ),
        ]),
      );

      expect(recommendations, hasLength(4));
      expect(
        _titles(recommendations),
        equals(<String>[
          'La última vuelta cayó frente a tu referencia',
          'Hay margen en repetibilidad',
          'El consumo por vuelta subió al final',
          'La última vuelta mezcló más freno y acelerador',
        ]),
      );
    });

    test('does not add a lap comparison recommendation when the delta is exactly 500 ms', () {
      final List<EngineerRecommendation> recommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'lap-best',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(),
          ),
          _lap(
            id: 'lap-last',
            lapNumber: 2,
            officialLapTimeMs: 60500,
            points: _comparisonPoints(speedBase: 100),
          ),
        ]),
      );

      expect(
        _titles(recommendations),
        isNot(contains('La última vuelta cayó frente a tu referencia')),
      );
      expect(recommendations, isEmpty);
    });

    test('adds a consistency recommendation when lap-time spread drops below the threshold', () {
      final List<EngineerRecommendation> recommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'lap-best',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(),
          ),
          _lap(
            id: 'lap-slow',
            lapNumber: 2,
            officialLapTimeMs: 70000,
            points: _comparisonPoints(speedBase: 101),
          ),
          _lap(
            id: 'lap-last',
            lapNumber: 3,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(speedBase: 102),
          ),
        ]),
      );

      expect(_titles(recommendations), contains('Hay margen en repetibilidad'));
      expect(
        _titles(recommendations),
        isNot(contains('La última vuelta cayó frente a tu referencia')),
      );
    });

    test('adds threshold-based fuel, overlap, and temperature recommendations near their boundaries', () {
      final List<EngineerRecommendation> fuelRecommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'lap-1',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(startFuel: 10, endFuel: 9),
          ),
          _lap(
            id: 'lap-2',
            lapNumber: 2,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(startFuel: 10, endFuel: 8.85),
          ),
        ]),
      );
      final List<EngineerRecommendation> overlapRecommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'lap-1',
            lapNumber: 1,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(count: 100, overlapCount: 10),
          ),
          _lap(
            id: 'lap-2',
            lapNumber: 2,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(count: 100, overlapCount: 19),
          ),
        ]),
      );
      final List<EngineerRecommendation> temperatureRecommendations =
          RecommendationEngine.build(
            _session([
              _lap(
                id: 'lap-1',
                lapNumber: 1,
                officialLapTimeMs: 60000,
                points: _comparisonPoints(tireTemps: const [80, 80, 80, 80]),
              ),
              _lap(
                id: 'lap-2',
                lapNumber: 2,
                officialLapTimeMs: 60000,
                points: _comparisonPoints(tireTemps: const [84, 84, 84, 84]),
              ),
            ]),
          );

      expect(_titles(fuelRecommendations), contains('El consumo por vuelta subió al final'));
      expect(
        _titles(overlapRecommendations),
        contains('La última vuelta mezcló más freno y acelerador'),
      );
      expect(
        _titles(temperatureRecommendations),
        contains('Las temperaturas medias subieron con la tanda'),
      );
    });

    test('ignores invalid laps and incomplete telemetry when evaluating heuristics', () {
      final List<EngineerRecommendation> recommendations = RecommendationEngine.build(
        _session([
          _lap(
            id: 'out-lap',
            lapNumber: 1,
            officialLapTimeMs: 90000,
            isOutLap: true,
            points: _comparisonPoints(
              startFuel: 20,
              endFuel: 10,
              tireTemps: const [120, 120, 120, 120],
              throttle: 0.8,
              brake: 0.8,
            ),
          ),
          _lap(
            id: 'lap-1',
            lapNumber: 2,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(),
          ),
          _lap(
            id: 'lap-2',
            lapNumber: 3,
            officialLapTimeMs: 60000,
            points: _comparisonPoints(),
          ),
        ]),
      );

      expect(recommendations, isEmpty);
    });
  });
}
