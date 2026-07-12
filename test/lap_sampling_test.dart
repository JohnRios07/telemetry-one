import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/storage/session_model.dart';
import 'package:telemetry_one/features/engineer/analytics/lap_sampling.dart';

void main() {
  final DateTime refDate = DateTime(2026);

  TelemetryPoint point({
    required int index,
    double speedKmh = 100,
    double throttle = 0.5,
    double brake = 0,
    double? posX,
    double? posY = 0,
    double? posZ = 0,
  }) {
    return TelemetryPoint(
      timestamp: refDate.add(Duration(milliseconds: index * 100)),
      speedKmh: speedKmh,
      rpm: 5000,
      gear: 4,
      throttle: throttle,
      brake: brake,
      posX: posX,
      posY: posY,
      posZ: posZ,
    );
  }

  CompleteLap lap(List<TelemetryPoint> points) {
    return CompleteLap(
      id: 'lap-1',
      lapNumber: 1,
      startTime: refDate,
      endTime: refDate.add(const Duration(seconds: 90)),
      officialLapTime: const Duration(seconds: 90),
      points: points,
    );
  }

  test('returns null when position data is incomplete', () {
    final NormalizedLapSample? sample = LapSampling.sampleByProgress(
      lap(<TelemetryPoint>[
        point(index: 0, posX: 0),
        point(index: 1, posX: null),
      ]),
    );

    expect(sample, isNull);
  });

  test('samples a lap into fixed progress buckets', () {
    final NormalizedLapSample? sample = LapSampling.sampleByProgress(
      lap(
        List<TelemetryPoint>.generate(11, (int index) {
          return point(
            index: index,
            speedKmh: 100 + index.toDouble(),
            throttle: 0.2 + (index * 0.05),
            posX: index.toDouble(),
          );
        }),
      ),
      bucketCount: 5,
    );

    expect(sample, isNotNull);
    expect(sample!.coverageRatio, 1.0);
    expect(sample.buckets, hasLength(5));
    expect(sample.buckets.first!.progress, closeTo(0, 0.0001));
    expect(sample.buckets.last!.progress, closeTo(1, 0.0001));
    expect(sample.buckets[2]!.speedKmh, closeTo(105, 0.001));
  });

  test('marks distant buckets as missing when coverage is too sparse', () {
    final NormalizedLapSample? sample = LapSampling.sampleByProgress(
      lap(<TelemetryPoint>[
        point(index: 0, posX: 0),
        point(index: 1, posX: 10),
      ]),
      bucketCount: 20,
    );

    expect(sample, isNotNull);
    expect(sample!.coverageRatio, lessThan(1));
    expect(sample.buckets.where((NormalizedLapBucket? bucket) => bucket == null),
        isNotEmpty);
  });
}
