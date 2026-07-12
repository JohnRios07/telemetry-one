import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/features/engineer/analytics/coach_analyzer.dart';
import 'package:telemetry_one/features/engineer/domain/coach_report.dart';

import 'support/coach_test_data.dart';

void main() {
  test('builds a session-local coach report', () {
    final CoachReport report = CoachAnalyzer.build(
      buildCoachSession([
        buildCoachLap(id: 'best', lapNumber: 1, officialLapTimeMs: 90000),
        buildCoachLap(
          id: 'lap-2',
          lapNumber: 2,
          officialLapTimeMs: 91400,
          weakTurns: const <int>{1},
        ),
        buildCoachLap(
          id: 'lap-3',
          lapNumber: 3,
          officialLapTimeMs: 92000,
          weakTurns: const <int>{1, 2},
        ),
        buildCoachLap(
          id: 'lap-4',
          lapNumber: 4,
          officialLapTimeMs: 91800,
          weakTurns: const <int>{2},
        ),
      ]),
    );

    expect(report.sessionId, 'coach-session');
    expect(report.disclaimer, contains('No es comparable entre autos o pistas'));
    expect(report.driverScore.isAvailable, isTrue);
    expect(report.weakSegments.isAvailable, isTrue);
  });

  test('filters invalid laps before composing the report', () {
    final CoachReport baseline = CoachAnalyzer.build(
      buildCoachSession([
        buildCoachLap(id: 'lap-1', lapNumber: 1, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-3', lapNumber: 3, officialLapTimeMs: 90000),
      ]),
    );
    final CoachReport report = CoachAnalyzer.build(
      buildCoachSession([
        buildCoachLap(
          id: 'out',
          lapNumber: 1,
          officialLapTimeMs: 130000,
          weakTurns: const <int>{1, 2, 3},
          isOutLap: true,
        ),
        buildCoachLap(id: 'lap-1', lapNumber: 2, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-2', lapNumber: 3, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-3', lapNumber: 4, officialLapTimeMs: 90000),
      ]),
    );

    expect(report.driverScore.isAvailable, isTrue);
    expect(report.driverScore.overallScore, baseline.driverScore.overallScore);
    expect(report.weakSegments.isAvailable, isFalse);
  });
}
