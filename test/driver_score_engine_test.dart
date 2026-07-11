import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/driver_score_engine.dart';
import 'package:telemetry_one/features/engineer/domain/coach_report.dart';

void main() {
  final DateTime refDate = DateTime(2026);

  TelemetryPoint point({
    required int index,
    bool overlap = false,
  }) {
    return TelemetryPoint(
      timestamp: refDate.add(Duration(milliseconds: index * 100)),
      speedKmh: 100,
      rpm: 5000,
      gear: 4,
      throttle: overlap ? 0.8 : 0.0,
      brake: overlap ? 0.8 : 0.0,
    );
  }

  CompleteLap lap({
    required String id,
    required int lapNumber,
    required int officialLapTimeMs,
    int overlapCount = 0,
    bool? isOutLap,
  }) {
    return CompleteLap(
      id: id,
      lapNumber: lapNumber,
      startTime: refDate,
      endTime: refDate.add(Duration(milliseconds: officialLapTimeMs)),
      officialLapTime: Duration(milliseconds: officialLapTimeMs),
      isOutLap: isOutLap,
      points: List<TelemetryPoint>.generate(100, (int index) {
        return point(index: index, overlap: index < overlapCount);
      }),
    );
  }

  Session session(List<CompleteLap> laps) {
    return Session(
      id: 'session-1',
      startTime: refDate,
      endTime: refDate.add(const Duration(minutes: 15)),
      laps: laps,
    );
  }

  test('returns unavailable with fewer than three valid laps', () {
    final DriverScoreResult result = DriverScoreEngine.build(
      session(<CompleteLap>[
        lap(id: 'lap-1', lapNumber: 1, officialLapTimeMs: 90000),
        lap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 90500),
      ]),
    );

    expect(result.isAvailable, isFalse);
    expect(result.confidence, CoachConfidence.unavailable);
  });

  test('applies weighting and overlap clamping for the overall score', () {
    final DriverScoreResult result = DriverScoreEngine.build(
      session(<CompleteLap>[
        lap(id: 'lap-1', lapNumber: 1, officialLapTimeMs: 100000, overlapCount: 18),
        lap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 100000, overlapCount: 18),
        lap(id: 'lap-3', lapNumber: 3, officialLapTimeMs: 100000, overlapCount: 18),
      ]),
    );

    expect(result.isAvailable, isTrue);
    expect(result.paceScore, 100);
    expect(result.consistencyScore, 100);
    expect(result.controlScore, 0);
    expect(result.overallScore, 80);
  });

  test('clamps pace score to zero when the median gap exceeds three percent', () {
    final DriverScoreResult result = DriverScoreEngine.build(
      session(<CompleteLap>[
        lap(id: 'lap-1', lapNumber: 1, officialLapTimeMs: 100000),
        lap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 104000),
        lap(id: 'lap-3', lapNumber: 3, officialLapTimeMs: 104000),
      ]),
    );

    expect(result.paceScore, 0);
    expect(result.overallScore, inInclusiveRange(40, 60));
  });

  test('filters invalid laps before scoring the session', () {
    final DriverScoreResult result = DriverScoreEngine.build(
      session(<CompleteLap>[
        lap(id: 'out', lapNumber: 1, officialLapTimeMs: 130000, overlapCount: 100, isOutLap: true),
        lap(id: 'lap-1', lapNumber: 2, officialLapTimeMs: 100000),
        lap(id: 'lap-2', lapNumber: 3, officialLapTimeMs: 100000),
        lap(id: 'lap-3', lapNumber: 4, officialLapTimeMs: 100000),
      ]),
    );

    expect(result.isAvailable, isTrue);
    expect(result.paceScore, 100);
    expect(result.controlScore, 100);
    expect(result.overallScore, 100);
  });
}
