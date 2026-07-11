import '../../../core/storage/session_model.dart';

enum ComparisonAlignmentMode {
  normalizedProgress,
  pointIndexFallback,
  unavailable,
}

enum ComparisonConfidence { unavailable, low, medium }

class LapComparisonPoint {
  final double progress;
  final double speedDeltaKmh;
  final double throttleDelta;
  final double brakeDelta;
  final Duration timeDelta;

  const LapComparisonPoint({
    required this.progress,
    required this.speedDeltaKmh,
    required this.throttleDelta,
    required this.brakeDelta,
    required this.timeDelta,
  });
}

class LapComparisonSummary {
  final CompleteLap bestLap;
  final CompleteLap lastLap;
  final Duration lapTimeDelta;
  final double averageSpeedDeltaKmh;
  final double averageThrottleDelta;
  final double averageBrakeDelta;

  const LapComparisonSummary({
    required this.bestLap,
    required this.lastLap,
    required this.lapTimeDelta,
    required this.averageSpeedDeltaKmh,
    required this.averageThrottleDelta,
    required this.averageBrakeDelta,
  });
}

class LapComparisonResult {
  final String sessionId;
  final bool isAvailable;
  final bool isBasic;
  final ComparisonAlignmentMode alignmentMode;
  final ComparisonConfidence confidence;
  final double coverageRatio;
  final String label;
  final String detail;
  final String? unavailableReason;
  final LapComparisonSummary? summary;
  final List<LapComparisonPoint> points;

  const LapComparisonResult({
    required this.sessionId,
    required this.isAvailable,
    required this.isBasic,
    required this.alignmentMode,
    required this.confidence,
    required this.coverageRatio,
    required this.label,
    required this.detail,
    required this.unavailableReason,
    required this.summary,
    required this.points,
  });

  factory LapComparisonResult.unavailable({
    required String sessionId,
    required String reason,
  }) {
    return LapComparisonResult(
      sessionId: sessionId,
      isAvailable: false,
      isBasic: true,
      alignmentMode: ComparisonAlignmentMode.unavailable,
      confidence: ComparisonConfidence.unavailable,
      coverageRatio: 0,
      label: 'Comparación básica V1 no disponible',
      detail: 'Faltan dos vueltas válidas comparables para este resumen local.',
      unavailableReason: reason,
      summary: null,
      points: const <LapComparisonPoint>[],
    );
  }
}
