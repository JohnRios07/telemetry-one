import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/weak_segment_detector.dart';
import 'package:telemetry_one/features/engineer/domain/coach_report.dart';

import 'support/coach_test_data.dart';

void main() {
  test('returns unavailable when there are fewer than three valid laps', () {
    final WeakSegmentAnalysis result = WeakSegmentDetector.analyze(
      buildCoachSession(<CompleteLap>[
        buildCoachLap(id: 'lap-1', lapNumber: 1, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 90500),
      ]),
    );

    expect(result.isAvailable, isFalse);
    expect(result.confidence, CoachConfidence.unavailable);
  });

  test('returns unavailable when laps do not have enough position data', () {
    final WeakSegmentAnalysis result = WeakSegmentDetector.analyze(
      buildCoachSession(<CompleteLap>[
        buildCoachLap(
          id: 'lap-1',
          lapNumber: 1,
          officialLapTimeMs: 90000,
          includePositions: false,
        ),
        buildCoachLap(
          id: 'lap-2',
          lapNumber: 2,
          officialLapTimeMs: 91000,
          includePositions: false,
        ),
        buildCoachLap(
          id: 'lap-3',
          lapNumber: 3,
          officialLapTimeMs: 91200,
          includePositions: false,
        ),
      ]),
    );

    expect(result.isAvailable, isFalse);
    expect(result.unavailableReason, contains('posición suficiente'));
  });

  test('keeps and ranks repeated weak segments', () {
    final WeakSegmentAnalysis result = WeakSegmentDetector.analyze(
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

    expect(result.isAvailable, isTrue);
    expect(result.confidence, CoachConfidence.basic);
    expect(result.segments, isNotEmpty);
    expect(result.segments.length, lessThanOrEqualTo(3));
    expect(result.segments.first.medianTimeLoss, greaterThanOrEqualTo(const Duration(milliseconds: 120)));
    expect(result.segments.first.coachingCue, isNotEmpty);

    if (result.segments.length > 1) {
      expect(
        result.segments.first.medianTimeLoss,
        greaterThanOrEqualTo(result.segments[1].medianTimeLoss),
      );
    }
  });

  test('does not invent weak segments when repeated loss thresholds are not met', () {
    final WeakSegmentAnalysis result = WeakSegmentDetector.analyze(
      buildCoachSession([
        buildCoachLap(id: 'best', lapNumber: 1, officialLapTimeMs: 90000),
        buildCoachLap(id: 'lap-2', lapNumber: 2, officialLapTimeMs: 90100),
        buildCoachLap(id: 'lap-3', lapNumber: 3, officialLapTimeMs: 90120),
      ]),
    );

    expect(result.isAvailable, isFalse);
    expect(result.unavailableReason, contains('pérdidas repetidas'));
  });
}
