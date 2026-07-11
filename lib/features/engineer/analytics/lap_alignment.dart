import 'dart:math' as math;

import '../../../core/storage/session_model.dart';
import 'lap_sampling.dart';
import '../domain/lap_comparison.dart';
import 'session_analyzer.dart';

class LapAlignment {
  const LapAlignment._();

  static LapComparisonResult compareSessionLaps(Session session) {
    final List<CompleteLap> laps = SessionAnalyzer.validLaps(session);
    if (laps.length < 2) {
      return LapComparisonResult.unavailable(
        sessionId: session.id,
        reason: 'La sesión necesita al menos dos vueltas válidas.',
      );
    }

    final CompleteLap bestLap = laps.reduce((
      CompleteLap current,
      CompleteLap next,
    ) {
      return current.officialLapTime <= next.officialLapTime ? current : next;
    });
    final CompleteLap lastLap = laps.last;

    if (bestLap.id == lastLap.id) {
      return LapComparisonResult.unavailable(
        sessionId: session.id,
        reason: 'La mejor vuelta y la última son la misma vuelta.',
      );
    }

    return compare(sessionId: session.id, bestLap: bestLap, lastLap: lastLap);
  }

  static LapComparisonResult compare({
    required String sessionId,
    required CompleteLap bestLap,
    required CompleteLap lastLap,
    int bucketCount = 100,
  }) {
    if (bestLap.points.length < 2 || lastLap.points.length < 2) {
      return LapComparisonResult.unavailable(
        sessionId: sessionId,
        reason: 'Faltan puntos suficientes para comparar vueltas locales.',
      );
    }

    final _PreparedLap bestPrepared = _PreparedLap.fromLap(bestLap, bucketCount);
    final _PreparedLap lastPrepared = _PreparedLap.fromLap(lastLap, bucketCount);
    final bool useProgressAlignment =
        bestPrepared.canUseProgressAlignment &&
        lastPrepared.canUseProgressAlignment;

    final List<_PreparedPoint?> bestSamples = useProgressAlignment
        ? bestPrepared.progressSamples
        : bestPrepared.indexSamples;
    final List<_PreparedPoint?> lastSamples = useProgressAlignment
        ? lastPrepared.progressSamples
        : lastPrepared.indexSamples;

    final List<LapComparisonPoint> points = <LapComparisonPoint>[];
    for (int index = 0; index < bucketCount; index += 1) {
      final _PreparedPoint? bestPoint = bestSamples[index];
      final _PreparedPoint? lastPoint = lastSamples[index];
      if (bestPoint == null || lastPoint == null) {
        continue;
      }

      final int bestTimeMs =
          (bestLap.officialLapTime.inMilliseconds * bestPoint.progress).round();
      final int lastTimeMs =
          (lastLap.officialLapTime.inMilliseconds * lastPoint.progress).round();

      points.add(
        LapComparisonPoint(
          progress: (bestPoint.progress + lastPoint.progress) / 2,
          speedDeltaKmh: lastPoint.speedKmh - bestPoint.speedKmh,
          throttleDelta: lastPoint.throttle - bestPoint.throttle,
          brakeDelta: lastPoint.brake - bestPoint.brake,
          timeDelta: Duration(milliseconds: lastTimeMs - bestTimeMs),
        ),
      );
    }

    if (points.length < math.max(8, bucketCount ~/ 5)) {
      return LapComparisonResult.unavailable(
        sessionId: sessionId,
        reason: 'La cobertura de puntos comparables es demasiado baja.',
      );
    }

    final double coverageRatio = points.length / bucketCount;
    final ComparisonAlignmentMode alignmentMode = useProgressAlignment
        ? ComparisonAlignmentMode.normalizedProgress
        : ComparisonAlignmentMode.pointIndexFallback;
    final ComparisonConfidence confidence =
        useProgressAlignment && coverageRatio >= 0.7
        ? ComparisonConfidence.medium
        : ComparisonConfidence.low;

    return LapComparisonResult(
      sessionId: sessionId,
      isAvailable: true,
      isBasic: true,
      alignmentMode: alignmentMode,
      confidence: confidence,
      coverageRatio: coverageRatio,
      label: 'Best lap vs Last lap',
      detail: useProgressAlignment
          ? 'Alineación por progreso normalizado con cobertura parcial de puntos.'
          : 'Fallback por índice de puntos. Úsalo como referencia básica, no de precisión por curva.',
      unavailableReason: null,
      summary: LapComparisonSummary(
        bestLap: bestLap,
        lastLap: lastLap,
        lapTimeDelta: lastLap.officialLapTime - bestLap.officialLapTime,
        averageSpeedDeltaKmh: _average(
          points.map((LapComparisonPoint point) => point.speedDeltaKmh),
        ),
        averageThrottleDelta: _average(
          points.map((LapComparisonPoint point) => point.throttleDelta),
        ),
        averageBrakeDelta: _average(
          points.map((LapComparisonPoint point) => point.brakeDelta),
        ),
      ),
      points: points,
    );
  }

  static double _average(Iterable<double> values) {
    final List<double> allValues = values.toList(growable: false);
    if (allValues.isEmpty) {
      return 0;
    }

    return allValues.reduce((double a, double b) => a + b) / allValues.length;
  }
}

class _PreparedLap {
  final bool canUseProgressAlignment;
  final List<_PreparedPoint?> progressSamples;
  final List<_PreparedPoint?> indexSamples;

  const _PreparedLap({
    required this.canUseProgressAlignment,
    required this.progressSamples,
    required this.indexSamples,
  });

  factory _PreparedLap.fromLap(CompleteLap lap, int bucketCount) {
    final List<_PreparedPoint> rawPoints = lap.points
        .map(_PreparedPoint.fromTelemetryPoint)
        .toList(growable: false);

    final NormalizedLapSample? progressSample = LapSampling.sampleByProgress(
      lap,
      bucketCount: bucketCount,
    );
    return _PreparedLap(
      canUseProgressAlignment: progressSample != null,
      progressSamples: progressSample == null
          ? List<_PreparedPoint?>.filled(bucketCount, null)
          : progressSample.buckets
                .map(_PreparedPoint.fromNormalizedBucket)
                .toList(growable: false),
      indexSamples: _sampleByIndex(rawPoints, bucketCount),
    );
  }

  static List<_PreparedPoint?> _sampleByIndex(
    List<_PreparedPoint> points,
    int bucketCount,
  ) {
    if (points.isEmpty) {
      return List<_PreparedPoint?>.filled(bucketCount, null);
    }

    if (points.length == 1) {
      return List<_PreparedPoint?>.generate(bucketCount, (int index) {
        final double progress = bucketCount <= 1
            ? 0
            : index / (bucketCount - 1);
        return points.single.copyWith(progress: progress);
      }, growable: false);
    }

    return List<_PreparedPoint?>.generate(bucketCount, (int index) {
      final double progress = bucketCount <= 1 ? 0 : index / (bucketCount - 1);
      final int pointIndex = (progress * (points.length - 1)).round().clamp(
        0,
        points.length - 1,
      );
      return points[pointIndex].copyWith(progress: progress);
    }, growable: false);
  }
}

class _PreparedPoint {
  final double progress;
  final double speedKmh;
  final double throttle;
  final double brake;
  final double? posX;
  final double? posY;
  final double? posZ;

  const _PreparedPoint({
    required this.progress,
    required this.speedKmh,
    required this.throttle,
    required this.brake,
    required this.posX,
    required this.posY,
    required this.posZ,
  });

  factory _PreparedPoint.fromTelemetryPoint(TelemetryPoint point) {
    return _PreparedPoint(
      progress: 0,
      speedKmh: point.speedKmh,
      throttle: point.throttle,
      brake: point.brake,
      posX: point.posX,
      posY: point.posY,
      posZ: point.posZ,
    );
  }

  static _PreparedPoint? fromNormalizedBucket(NormalizedLapBucket? bucket) {
    if (bucket == null) {
      return null;
    }

    return _PreparedPoint(
      progress: bucket.progress,
      speedKmh: bucket.speedKmh,
      throttle: bucket.throttle,
      brake: bucket.brake,
      posX: bucket.posX,
      posY: bucket.posY,
      posZ: bucket.posZ,
    );
  }

  _PreparedPoint copyWith({double? progress}) {
    return _PreparedPoint(
      progress: progress ?? this.progress,
      speedKmh: speedKmh,
      throttle: throttle,
      brake: brake,
      posX: posX,
      posY: posY,
      posZ: posZ,
    );
  }
}
