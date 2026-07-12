import 'dart:math' as math;

import '../../../core/storage/session_model.dart';

class NormalizedLapSample {
  final List<NormalizedLapBucket?> buckets;
  final double coverageRatio;

  const NormalizedLapSample({
    required this.buckets,
    required this.coverageRatio,
  });
}

class NormalizedLapBucket {
  final int bucketIndex;
  final double progress;
  final double speedKmh;
  final double throttle;
  final double brake;
  final double posX;
  final double posY;
  final double posZ;

  const NormalizedLapBucket({
    required this.bucketIndex,
    required this.progress,
    required this.speedKmh,
    required this.throttle,
    required this.brake,
    required this.posX,
    required this.posY,
    required this.posZ,
  });
}

class LapSampling {
  const LapSampling._();

  static NormalizedLapSample? sampleByProgress(
    CompleteLap lap, {
    int bucketCount = 100,
    double maxDistanceToBucket = 0.08,
  }) {
    if (lap.points.length < 2) {
      return null;
    }

    final List<_TrackPoint> trackPoints = <_TrackPoint>[];
    for (final TelemetryPoint point in lap.points) {
      if (point.posX == null || point.posY == null || point.posZ == null) {
        return null;
      }

      trackPoints.add(
        _TrackPoint(
          speedKmh: point.speedKmh,
          throttle: point.throttle,
          brake: point.brake,
          posX: point.posX!,
          posY: point.posY!,
          posZ: point.posZ!,
        ),
      );
    }

    final List<double> cumulativeDistance = <double>[0];
    double totalDistance = 0;
    for (int index = 1; index < trackPoints.length; index += 1) {
      final _TrackPoint previous = trackPoints[index - 1];
      final _TrackPoint current = trackPoints[index];
      final double dx = current.posX - previous.posX;
      final double dy = current.posY - previous.posY;
      final double dz = current.posZ - previous.posZ;
      totalDistance += math.sqrt((dx * dx) + (dy * dy) + (dz * dz));
      cumulativeDistance.add(totalDistance);
    }

    if (totalDistance <= 0) {
      return null;
    }

    final List<_TrackPoint> normalizedPoints = <_TrackPoint>[];
    for (int index = 0; index < trackPoints.length; index += 1) {
      normalizedPoints.add(
        trackPoints[index].copyWith(progress: cumulativeDistance[index] / totalDistance),
      );
    }

    final List<NormalizedLapBucket?> buckets = List<NormalizedLapBucket?>.generate(
      bucketCount,
      (int index) {
        final double targetProgress = bucketCount <= 1 ? 0 : index / (bucketCount - 1);
        _TrackPoint? closest;
        double? smallestDistance;

        for (final _TrackPoint point in normalizedPoints) {
          final double distance = (point.progress - targetProgress).abs();
          if (smallestDistance == null || distance < smallestDistance) {
            smallestDistance = distance;
            closest = point;
          }
        }

        if (closest == null ||
            (smallestDistance != null && smallestDistance > maxDistanceToBucket)) {
          return null;
        }

        return NormalizedLapBucket(
          bucketIndex: index,
          progress: closest.progress,
          speedKmh: closest.speedKmh,
          throttle: closest.throttle,
          brake: closest.brake,
          posX: closest.posX,
          posY: closest.posY,
          posZ: closest.posZ,
        );
      },
      growable: false,
    );

    final int coveredBuckets = buckets.whereType<NormalizedLapBucket>().length;
    return NormalizedLapSample(
      buckets: buckets,
      coverageRatio: bucketCount == 0 ? 0 : coveredBuckets / bucketCount,
    );
  }
}

class _TrackPoint {
  final double progress;
  final double speedKmh;
  final double throttle;
  final double brake;
  final double posX;
  final double posY;
  final double posZ;

  const _TrackPoint({
    this.progress = 0,
    required this.speedKmh,
    required this.throttle,
    required this.brake,
    required this.posX,
    required this.posY,
    required this.posZ,
  });

  _TrackPoint copyWith({double? progress}) {
    return _TrackPoint(
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
