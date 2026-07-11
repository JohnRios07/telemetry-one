import 'dart:math' as math;

import '../../../core/storage/session_model.dart';
import '../domain/coach_report.dart';
import 'lap_sampling.dart';
import 'session_analyzer.dart';

class WeakSegmentDetector {
  const WeakSegmentDetector._();

  static WeakSegmentAnalysis analyze(Session session, {int bucketCount = 120}) {
    final List<CompleteLap> validLaps = SessionAnalyzer.validLaps(session);
    if (validLaps.length < 3) {
      return WeakSegmentAnalysis.unavailable(
        reason: 'No hay suficientes vueltas válidas para cerrar coaching local.',
      );
    }

    final CompleteLap referenceLap = validLaps.reduce((CompleteLap current, CompleteLap next) {
      return current.officialLapTime <= next.officialLapTime ? current : next;
    });
    final NormalizedLapSample? referenceSample = LapSampling.sampleByProgress(
      referenceLap,
      bucketCount: bucketCount,
    );
    if (referenceSample == null || referenceSample.coverageRatio < 0.75) {
      return WeakSegmentAnalysis.unavailable(
        reason: 'La mejor vuelta no tiene posición suficiente para segmentar sin inventar curvas.',
      );
    }

    final List<_ComparableLap> comparableLaps = validLaps
        .where((CompleteLap lap) => lap.id != referenceLap.id)
        .map((CompleteLap lap) {
          return _ComparableLap(
            lap: lap,
            sample: LapSampling.sampleByProgress(lap, bucketCount: bucketCount),
          );
        })
        .where((_ComparableLap item) => item.sample != null && item.sample!.coverageRatio >= 0.75)
        .toList(growable: false);

    if (comparableLaps.length < 2) {
      return WeakSegmentAnalysis.unavailable(
        reason: 'No hay suficientes vueltas comparables para cerrar coaching local.',
      );
    }

    final List<_BucketSegment> candidateSegments = _detectSegments(
      referenceSample.buckets,
    );
    if (candidateSegments.isEmpty) {
      return WeakSegmentAnalysis.unavailable(
        reason: 'No se detectaron segmentos repetibles con señal local suficiente.',
      );
    }

    final List<_SegmentResult> repeatedWeakness = <_SegmentResult>[];
    for (final _BucketSegment segment in candidateSegments) {
      final _SegmentResult? result = _buildSegmentInsight(
        referenceLap: referenceLap,
        referenceSample: referenceSample,
        comparableLaps: comparableLaps,
        segment: segment,
      );
      if (result != null) {
        repeatedWeakness.add(result);
      }
    }

    if (repeatedWeakness.isEmpty) {
      return WeakSegmentAnalysis.unavailable(
        reason: 'No hay pérdidas repetidas suficientemente claras frente a la mejor vuelta local.',
      );
    }

    repeatedWeakness.sort((_SegmentResult a, _SegmentResult b) {
      final int timeCompare = b.insight.medianTimeLoss.compareTo(a.insight.medianTimeLoss);
      if (timeCompare != 0) {
        return timeCompare;
      }
      final int apexCompare = b.insight.medianApexSpeedLossKmh.compareTo(a.insight.medianApexSpeedLossKmh);
      if (apexCompare != 0) {
        return apexCompare;
      }
      final int delayA = a.insight.medianThrottlePickupDelay?.inMilliseconds ?? 0;
      final int delayB = b.insight.medianThrottlePickupDelay?.inMilliseconds ?? 0;
      return delayB.compareTo(delayA);
    });

    final CoachConfidence confidence = comparableLaps.length >= 3
        ? CoachConfidence.basic
        : CoachConfidence.low;

    final List<WeakSegmentInsight> segments = repeatedWeakness
        .take(3)
        .map((_SegmentResult result) => result.insight)
        .toList(growable: false);

    return WeakSegmentAnalysis(
      isAvailable: true,
      confidence: confidence,
      unavailableReason: null,
      segments: segments,
    );
  }

  static List<_BucketSegment> _detectSegments(List<NormalizedLapBucket?> buckets) {
    final List<bool> flags = List<bool>.filled(buckets.length, false);
    for (int index = 1; index < buckets.length - 1; index += 1) {
      final NormalizedLapBucket? previous = buckets[index - 1];
      final NormalizedLapBucket? current = buckets[index];
      final NormalizedLapBucket? next = buckets[index + 1];
      if (previous == null || current == null || next == null) {
        continue;
      }

      final double headingA = math.atan2(
        current.posZ - previous.posZ,
        current.posX - previous.posX,
      );
      final double headingB = math.atan2(
        next.posZ - current.posZ,
        next.posX - current.posX,
      );
      final double curvature = _wrappedAngle(headingB - headingA).abs();
      final bool cornerLike = (curvature >= 0.10 &&
              (current.brake >= 0.05 || current.throttle <= 0.55)) ||
          current.brake >= 0.15 ||
          current.throttle <= 0.40;
      flags[index] = cornerLike;
    }

    for (int index = 1; index < flags.length - 1; index += 1) {
      if (!flags[index] && flags[index - 1] && flags[index + 1]) {
        flags[index] = true;
      }
    }

    final List<_BucketSegment> segments = <_BucketSegment>[];
    int? start;
    int segmentNumber = 1;
    for (int index = 0; index < flags.length; index += 1) {
      if (flags[index]) {
        start ??= index;
        continue;
      }

      if (start != null) {
        final int end = index - 1;
        if ((end - start) + 1 >= 4) {
          segments.add(
            _BucketSegment(
              segmentNumber: segmentNumber,
              start: start,
              end: end,
            ),
          );
          segmentNumber += 1;
        }
        start = null;
      }
    }

    if (start != null) {
      final int end = flags.length - 1;
      if ((end - start) + 1 >= 4) {
        segments.add(
          _BucketSegment(
            segmentNumber: segmentNumber,
            start: start,
            end: end,
          ),
        );
      }
    }

    return segments;
  }

  static _SegmentResult? _buildSegmentInsight({
    required CompleteLap referenceLap,
    required NormalizedLapSample referenceSample,
    required List<_ComparableLap> comparableLaps,
    required _BucketSegment segment,
  }) {
    final List<NormalizedLapBucket> referenceBuckets = referenceSample.buckets
        .sublist(segment.start, segment.end + 1)
        .whereType<NormalizedLapBucket>()
        .toList(growable: false);
    if (referenceBuckets.length < 3) {
      return null;
    }

    final double referenceStartProgress = referenceBuckets.first.progress;
    final double referenceEndProgress = referenceBuckets.last.progress;
    if (referenceEndProgress <= referenceStartProgress) {
      return null;
    }

    final double referenceApexSpeed = referenceBuckets
        .map((NormalizedLapBucket bucket) => bucket.speedKmh)
        .reduce(math.min);
    final Duration referencePickupDelay = _pickupDelay(
          buckets: referenceBuckets,
          lapTime: referenceLap.officialLapTime,
        ) ??
        Duration.zero;

    final List<Duration> timeLosses = <Duration>[];
    final List<double> apexSpeedLosses = <double>[];
    final List<Duration> pickupDelays = <Duration>[];
    final List<double> overlapRatios = <double>[];

    for (final _ComparableLap comparableLap in comparableLaps) {
      final List<NormalizedLapBucket> lapBuckets = comparableLap.sample!.buckets
          .sublist(segment.start, segment.end + 1)
          .whereType<NormalizedLapBucket>()
          .toList(growable: false);
      if (lapBuckets.length < 3) {
        continue;
      }

      final double lapStartProgress = lapBuckets.first.progress;
      final double lapEndProgress = lapBuckets.last.progress;
      if (lapEndProgress <= lapStartProgress) {
        continue;
      }

      final Duration estimatedReferenceTime = _durationFromProgressSpan(
        lapTime: referenceLap.officialLapTime,
        startProgress: referenceStartProgress,
        endProgress: referenceEndProgress,
      );
      final Duration estimatedLapTime = _durationFromProgressSpan(
        lapTime: comparableLap.lap.officialLapTime,
        startProgress: lapStartProgress,
        endProgress: lapEndProgress,
      );
      final Duration timeLoss = estimatedLapTime - estimatedReferenceTime;
      timeLosses.add(timeLoss);

      final double lapApexSpeed = lapBuckets
          .map((NormalizedLapBucket bucket) => bucket.speedKmh)
          .reduce(math.min);
      apexSpeedLosses.add(math.max(0, referenceApexSpeed - lapApexSpeed));

      final Duration? lapPickupDelay = _pickupDelay(
        buckets: lapBuckets,
        lapTime: comparableLap.lap.officialLapTime,
      );
      if (lapPickupDelay != null) {
        final Duration delta = lapPickupDelay - referencePickupDelay;
        if (delta > Duration.zero) {
          pickupDelays.add(delta);
        }
      }

      overlapRatios.add(_overlapRatio(lapBuckets));
    }

    if (timeLosses.length < 2) {
      return null;
    }

    final Duration medianTimeLoss = _medianDuration(timeLosses);
    final int repeatedLossCount = timeLosses
        .where((Duration loss) => loss >= const Duration(milliseconds: 80))
        .length;
    if (medianTimeLoss < const Duration(milliseconds: 120) ||
        repeatedLossCount * 2 < timeLosses.length) {
      return null;
    }

    final double medianApexSpeedLoss = _medianDouble(apexSpeedLosses);
    final Duration? medianPickupDelay = pickupDelays.isEmpty
        ? null
        : _medianDuration(pickupDelays);
    final double medianOverlapRatio = overlapRatios.isEmpty
        ? 0
        : _medianDouble(overlapRatios);
    final int segmentIndex = segment.segmentNumber;

    return _SegmentResult(
      insight: WeakSegmentInsight(
        segmentIndex: segmentIndex,
        label: 'Segment $segmentIndex',
        startProgress: referenceStartProgress,
        endProgress: referenceEndProgress,
        medianTimeLoss: medianTimeLoss,
        referenceApexSpeedKmh: referenceApexSpeed,
        medianApexSpeedLossKmh: medianApexSpeedLoss,
        medianThrottlePickupDelay: medianPickupDelay,
        coachingCue: _buildCue(
          medianApexSpeedLossKmh: medianApexSpeedLoss,
          medianThrottlePickupDelay: medianPickupDelay,
          medianOverlapRatio: medianOverlapRatio,
        ),
      ),
    );
  }

  static Duration _durationFromProgressSpan({
    required Duration lapTime,
    required double startProgress,
    required double endProgress,
  }) {
    final double span = (endProgress - startProgress).clamp(0.0, 1.0);
    return Duration(milliseconds: (lapTime.inMilliseconds * span).round());
  }

  static Duration? _pickupDelay({
    required List<NormalizedLapBucket> buckets,
    required Duration lapTime,
  }) {
    if (buckets.isEmpty) {
      return null;
    }

    int apexIndex = 0;
    double apexSpeed = buckets.first.speedKmh;
    for (int index = 1; index < buckets.length; index += 1) {
      if (buckets[index].speedKmh < apexSpeed) {
        apexSpeed = buckets[index].speedKmh;
        apexIndex = index;
      }
    }

    for (int index = apexIndex; index < buckets.length; index += 1) {
      final NormalizedLapBucket bucket = buckets[index];
      if (bucket.throttle >= 0.60 && bucket.brake <= 0.05) {
        final double progressDelta = bucket.progress - buckets[apexIndex].progress;
        return Duration(milliseconds: (lapTime.inMilliseconds * progressDelta).round());
      }
    }

    return null;
  }

  static double _overlapRatio(List<NormalizedLapBucket> buckets) {
    if (buckets.isEmpty) {
      return 0;
    }

    final int overlapCount = buckets
        .where((NormalizedLapBucket bucket) => bucket.throttle >= 0.15 && bucket.brake >= 0.15)
        .length;
    return overlapCount / buckets.length;
  }

  static Duration _medianDuration(List<Duration> durations) {
    final List<int> values = durations
        .map((Duration duration) => duration.inMilliseconds)
        .toList(growable: false)
      ..sort();
    final int middle = values.length ~/ 2;
    if (values.length.isOdd) {
      return Duration(milliseconds: values[middle]);
    }

    return Duration(milliseconds: ((values[middle - 1] + values[middle]) / 2).round());
  }

  static double _medianDouble(List<double> values) {
    final List<double> sortedValues = List<double>.from(values)..sort();
    final int middle = sortedValues.length ~/ 2;
    if (sortedValues.length.isOdd) {
      return sortedValues[middle];
    }

    return (sortedValues[middle - 1] + sortedValues[middle]) / 2;
  }

  static double _wrappedAngle(double value) {
    if (value > math.pi) {
      return value - (2 * math.pi);
    }
    if (value < -math.pi) {
      return value + (2 * math.pi);
    }
    return value;
  }

  static String _buildCue({
    required double medianApexSpeedLossKmh,
    required Duration? medianThrottlePickupDelay,
    required double medianOverlapRatio,
  }) {
    final bool hasApexLoss = medianApexSpeedLossKmh >= 4;
    final bool hasPickupDelay =
        (medianThrottlePickupDelay?.inMilliseconds ?? 0) >= 120;
    final bool hasOverlap = medianOverlapRatio >= 0.18;

    if (hasApexLoss && hasPickupDelay) {
      return 'Menor velocidad de apex y vuelta al gas más tardía que tu best lap.';
    }
    if (hasApexLoss) {
      return 'Pasás por el apex con menos velocidad que la referencia local.';
    }
    if (hasPickupDelay) {
      return 'Volvés al acelerador más tarde que en tu mejor vuelta local.';
    }
    if (hasOverlap) {
      return 'Hay mezcla de freno y acelerador dentro del segmento.';
    }
    return 'Perdés tiempo de forma repetida frente a tu mejor vuelta local.';
  }
}

class _ComparableLap {
  final CompleteLap lap;
  final NormalizedLapSample? sample;

  const _ComparableLap({required this.lap, required this.sample});
}

class _BucketSegment {
  final int segmentNumber;
  final int start;
  final int end;

  const _BucketSegment({
    required this.segmentNumber,
    required this.start,
    required this.end,
  });
}

class _SegmentResult {
  final WeakSegmentInsight insight;

  const _SegmentResult({required this.insight});
}
