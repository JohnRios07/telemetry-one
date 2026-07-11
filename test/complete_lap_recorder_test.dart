import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';
import 'package:telemetry_one/core/recording/complete_lap_recorder.dart';

void main() {
  group('CompleteLapRecorder', () {
    test('records only a completed lap after a clean lap start', () {
      final recorder = CompleteLapRecorder();
      final start = DateTime(2026);

      recorder
        ..ingest(
          _data(
            timestamp: start,
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(milliseconds: 500),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 10)),
            packetId: 2,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 10),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 91)),
            packetId: 3,
            currentLap: 2,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: const Duration(seconds: 91),
          ),
        );

      expect(recorder.completedLaps, hasLength(1));
      expect(recorder.completedLaps.single.lapNumber, 1);
      expect(
        recorder.completedLaps.single.officialLapTime,
        const Duration(seconds: 91),
      );
      expect(recorder.completedLaps.single.points, hasLength(2));
    });

    test('starting mid-lap arms without saving that lap', () {
      final recorder = CompleteLapRecorder();
      final start = DateTime(2026);

      recorder
        ..ingest(
          _data(
            timestamp: start,
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 30),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 60)),
            packetId: 2,
            currentLap: 2,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: const Duration(seconds: 60),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 150)),
            packetId: 3,
            currentLap: 3,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: const Duration(seconds: 90),
          ),
        );

      expect(recorder.completedLaps, hasLength(1));
      expect(recorder.completedLaps.single.lapNumber, 2);
    });

    test('ignores duplicate packets', () {
      final recorder = CompleteLapRecorder();
      final start = DateTime(2026);

      recorder
        ..ingest(
          _data(
            timestamp: start,
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(milliseconds: 500),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 1)),
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 1),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 90)),
            packetId: 2,
            currentLap: 2,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: const Duration(seconds: 90),
          ),
        );

      expect(recorder.completedLaps.single.points, hasLength(1));
    });

    test('packet rewind invalidates candidate and rearms', () {
      final recorder = CompleteLapRecorder();
      final start = DateTime(2026);

      recorder
        ..ingest(
          _data(
            timestamp: start,
            packetId: 10,
            currentLap: 1,
            currentLapTime: const Duration(milliseconds: 500),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 10)),
            packetId: 11,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 10),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 11)),
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 11),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 90)),
            packetId: 2,
            currentLap: 2,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: const Duration(seconds: 90),
          ),
        );

      expect(recorder.completedLaps, isEmpty);
    });

    test('uses elapsed time fallback when lastLapTime is null', () {
      final recorder = CompleteLapRecorder();
      final start = DateTime(2026);

      recorder
        ..ingest(
          _data(
            timestamp: start,
            packetId: 1,
            currentLap: 1,
            currentLapTime: const Duration(milliseconds: 500),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 12)),
            packetId: 2,
            currentLap: 1,
            currentLapTime: const Duration(seconds: 12),
          ),
        )
        ..ingest(
          _data(
            timestamp: start.add(const Duration(seconds: 90)),
            packetId: 3,
            currentLap: 2,
            currentLapTime: const Duration(milliseconds: 200),
            lastLapTime: null,
          ),
        );

      expect(recorder.completedLaps, hasLength(1));
      expect(
        recorder.completedLaps.single.officialLapTime,
        const Duration(seconds: 90),
      );
    });
  });
}

TelemetryData _data({
  required DateTime timestamp,
  required int packetId,
  required int currentLap,
  required Duration currentLapTime,
  Duration? lastLapTime,
}) {
  return TelemetryData(
    timestamp: timestamp,
    packetId: packetId,
    currentLap: currentLap,
    currentLapTime: currentLapTime,
    lastLapTime: lastLapTime,
    speedKmh: 100,
    rpm: 7000,
    gear: 3,
    throttle: 0.8,
    brake: 0,
  );
}
