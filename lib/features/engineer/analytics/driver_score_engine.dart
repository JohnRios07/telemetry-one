import '../../../core/storage/session_model.dart';
import '../domain/coach_report.dart';
import '../domain/session_summary.dart';
import 'session_analyzer.dart';

class DriverScoreEngine {
  const DriverScoreEngine._();

  static DriverScoreResult build(Session session) {
    final List<CompleteLap> laps = SessionAnalyzer.validLaps(session);
    if (laps.length < 3) {
      return DriverScoreResult.unavailable(
        reason: 'Se necesitan al menos tres vueltas válidas para cerrar un score local.',
      );
    }

    final SessionSummary summary = SessionAnalyzer.buildSummary(session);
    final Duration bestLap = laps
        .map((CompleteLap lap) => lap.officialLapTime)
        .reduce((Duration a, Duration b) => a <= b ? a : b);
    final Duration medianLap = _medianLap(laps);
    final double paceGapRatio =
        (medianLap.inMilliseconds - bestLap.inMilliseconds) / bestLap.inMilliseconds;
    final int paceScore = _scoreFromRatio(paceGapRatio, maxRatio: 0.03);

    final double consistencyValue = summary.consistency.value ?? 0;
    final int consistencyScore = consistencyValue.round().clamp(0, 100);

    final double averageOverlap = laps
            .map(SessionAnalyzer.brakeThrottleOverlapRatio)
            .reduce((double a, double b) => a + b) /
        laps.length;
    final int controlScore = _scoreFromRatio(averageOverlap, maxRatio: 0.18);

    final int overallScore = ((paceScore * 0.4) +
            (consistencyScore * 0.4) +
            (controlScore * 0.2))
        .round()
        .clamp(0, 100);

    final CoachConfidence confidence = laps.length >= 5
        ? CoachConfidence.basic
        : CoachConfidence.low;

    return DriverScoreResult(
      isAvailable: true,
      confidence: confidence,
      overallScore: overallScore,
      paceScore: paceScore,
      consistencyScore: consistencyScore,
      controlScore: controlScore,
      unavailableReason: null,
      explanation:
          'Score local de sesión: pace ${_bandLabel(paceScore)}, consistencia ${_bandLabel(consistencyScore)} y control ${_bandLabel(controlScore)} frente a tus vueltas válidas guardadas.',
    );
  }

  static Duration _medianLap(List<CompleteLap> laps) {
    final List<int> lapTimes = laps
        .map((CompleteLap lap) => lap.officialLapTime.inMilliseconds)
        .toList(growable: false)
      ..sort();
    final int middle = lapTimes.length ~/ 2;
    if (lapTimes.length.isOdd) {
      return Duration(milliseconds: lapTimes[middle]);
    }

    return Duration(milliseconds: ((lapTimes[middle - 1] + lapTimes[middle]) / 2).round());
  }

  static int _scoreFromRatio(double ratio, {required double maxRatio}) {
    final double normalized = (1 - (ratio / maxRatio).clamp(0.0, 1.0)) * 100;
    return normalized.round().clamp(0, 100);
  }

  static String _bandLabel(int score) {
    if (score >= 85) {
      return 'fuerte';
    }
    if (score >= 70) {
      return 'aceptable';
    }
    if (score >= 50) {
      return 'irregular';
    }
    return 'flojo';
  }
}
