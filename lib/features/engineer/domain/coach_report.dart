enum CoachConfidence { unavailable, low, basic }

class CoachReport {
  final String sessionId;
  final WeakSegmentAnalysis weakSegments;
  final DriverScoreResult driverScore;
  final String disclaimer;

  const CoachReport({
    required this.sessionId,
    required this.weakSegments,
    required this.driverScore,
    required this.disclaimer,
  });
}

class WeakSegmentAnalysis {
  final bool isAvailable;
  final CoachConfidence confidence;
  final String? unavailableReason;
  final List<WeakSegmentInsight> segments;

  const WeakSegmentAnalysis({
    required this.isAvailable,
    required this.confidence,
    required this.unavailableReason,
    required this.segments,
  });

  factory WeakSegmentAnalysis.unavailable({required String reason}) {
    return WeakSegmentAnalysis(
      isAvailable: false,
      confidence: CoachConfidence.unavailable,
      unavailableReason: reason,
      segments: const <WeakSegmentInsight>[],
    );
  }
}

class WeakSegmentInsight {
  final int segmentIndex;
  final String label;
  final double startProgress;
  final double endProgress;
  final Duration medianTimeLoss;
  final double referenceApexSpeedKmh;
  final double medianApexSpeedLossKmh;
  final Duration? medianThrottlePickupDelay;
  final String coachingCue;

  const WeakSegmentInsight({
    required this.segmentIndex,
    required this.label,
    required this.startProgress,
    required this.endProgress,
    required this.medianTimeLoss,
    required this.referenceApexSpeedKmh,
    required this.medianApexSpeedLossKmh,
    required this.medianThrottlePickupDelay,
    required this.coachingCue,
  });
}

class DriverScoreResult {
  final bool isAvailable;
  final CoachConfidence confidence;
  final int overallScore;
  final int paceScore;
  final int consistencyScore;
  final int controlScore;
  final String? unavailableReason;
  final String explanation;

  const DriverScoreResult({
    required this.isAvailable,
    required this.confidence,
    required this.overallScore,
    required this.paceScore,
    required this.consistencyScore,
    required this.controlScore,
    required this.unavailableReason,
    required this.explanation,
  });

  factory DriverScoreResult.unavailable({required String reason}) {
    return DriverScoreResult(
      isAvailable: false,
      confidence: CoachConfidence.unavailable,
      overallScore: 0,
      paceScore: 0,
      consistencyScore: 0,
      controlScore: 0,
      unavailableReason: reason,
      explanation: reason,
    );
  }
}
