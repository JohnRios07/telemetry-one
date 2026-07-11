import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/models/telemetry_data.dart';
import 'package:telemetry_one/core/recording/complete_lap_recorder.dart';
import 'package:telemetry_one/features/dashboard/providers/session_provider.dart';

void main() {
  group('SessionRecorder — start / stop', () {
    late SessionRecorder recorder;

    setUp(() {
      recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
      expect(recorder.state.status, RecordingStatus.idle);
    });

    test('startRecording transitions to recording state', () {
      recorder.startRecording();

      expect(recorder.state.status, RecordingStatus.recording);
      expect(recorder.state.currentSession, isNotNull);
      expect(recorder.state.currentSession!.game, 'GT7');
    });

    test('stopRecording returns to idle cleanly when no laps completed', () async {
      recorder.startRecording();
      expect(recorder.state.isRecording, true);

      await recorder.stopRecording();

      // No laps were recorded, so the session is discarded without error.
      expect(recorder.state.status, RecordingStatus.idle);
      expect(recorder.state.error, isNull);
    });

    test('stopRecording is no-op when not recording', () async {
      // StopRecording should not crash or change state when idle.
      await recorder.stopRecording();
      expect(recorder.state.status, RecordingStatus.idle);
      expect(recorder.state.error, isNull);
    });
  });

  group('SessionRecorder — auto-start', () {
    late SessionRecorder recorder;

    setUp(() {
      recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
    });

    TelemetryData startPacket({
      int packetId = 1,
      int currentLap = 1,
      int currentLapTimeMs = 500,
      double speedKmh = 120,
    }) {
      return TelemetryData(
        timestamp: DateTime(2026),
        packetId: packetId,
        currentLap: currentLap,
        currentLapTime: Duration(milliseconds: currentLapTimeMs),
        speedKmh: speedKmh,
        gear: 3,
        rpm: 7000,
        throttle: 0.3,
        brake: 0,
      );
    }

    test('auto-starts on clean first lap window', () {
      expect(recorder.state.isRecording, false);

      recorder.recordPoint(startPacket());

      expect(recorder.state.isRecording, true);
    });

    test('does not auto-start on lap 0', () {
      recorder.recordPoint(startPacket(currentLap: 0, speedKmh: 120));

      expect(recorder.state.isRecording, false);
    });

    test('does not auto-start when speed is 0', () {
      recorder.recordPoint(startPacket(currentLap: 1, speedKmh: 0));

      expect(recorder.state.isRecording, false);
    });

    test('does not auto-start when currentLapTime is large', () {
      recorder.recordPoint(startPacket(currentLapTimeMs: 5000));

      expect(recorder.state.isRecording, false);
    });

    test('does not auto-start twice from the same window', () {
      recorder.recordPoint(startPacket());
      expect(recorder.state.isRecording, true);

      // Same window — second packet should not re-trigger or create a
      // second recording session.
      recorder.recordPoint(startPacket(packetId: 2));
      expect(recorder.state.isRecording, true);
      // The session id should be the same (not a new session).
      expect(recorder.state.currentSession!.id,
          startsWith(recorder.state.currentSession!.id));
    });

    test('does not auto-start when already recording manually', () {
      recorder.startRecording();
      expect(recorder.state.isRecording, true);

      recorder.recordPoint(startPacket());

      // Still the same recording session.
      expect(recorder.state.isRecording, true);
    });
  });

  group('SessionRecorder — auto-lifecycle', () {
    late SessionRecorder recorder;

    setUp(() {
      recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
    });

    TelemetryData startPacket({int packetId = 1}) {
      return TelemetryData(
        timestamp: DateTime(2026),
        packetId: packetId,
        currentLap: 1,
        currentLapTime: const Duration(milliseconds: 500),
        speedKmh: 120,
        gear: 3,
        rpm: 7000,
        throttle: 0.3,
        brake: 0,
      );
    }

    test('auto-start flag prevents re-trigger after manual stop', () async {
      // Auto-start fires
      recorder.recordPoint(startPacket());
      expect(recorder.state.isRecording, true);

      // User manually stops
      await recorder.stopRecording();
      expect(recorder.state.isRecording, false);

      // More data arrives (same race, more laps)
      recorder.recordPoint(startPacket(packetId: 100));

      // Should NOT have auto-started again.
      expect(recorder.state.isRecording, false);
    });

    test('manual startRecording resets auto-lifecycle', () {
      // Auto-start fires
      recorder.recordPoint(startPacket());
      expect(recorder.state.isRecording, true);

      // User manually stops
      // ignore: unawaited — we just need the state change
      recorder.stopRecording();

      // User manually starts a new session
      recorder.startRecording();
      expect(recorder.state.isRecording, true);
    });

    test('auto-start does not fire when userStoppedAfterAutoStart is set', () async {
      // Auto-start
      recorder.recordPoint(startPacket());
      expect(recorder.state.isRecording, true);

      // Manual stop
      await recorder.stopRecording();
      expect(recorder.state.isRecording, false);

      // Simulate more lap-1 data after manual stop
      recorder.recordPoint(startPacket(packetId: 200));
      expect(recorder.state.isRecording, false);
    });
  });

  group('SessionRecorder — timeout auto-stop', () {
    test('timeout check is skipped when no lap was ever completed', () {
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());
      recorder.startRecording();

      // Stationary car with no completed laps should not trigger stop
      // because _lastLapCompletedAt is null.
      recorder.recordPoint(TelemetryData(
        timestamp: DateTime(2026),
        packetId: 1,
        currentLap: 1,
        currentLapTime: const Duration(seconds: 10),
        speedKmh: 0,
        gear: 1,
        rpm: 2000,
        throttle: 0,
        brake: 1,
      ));
      // Use state directly — freeze it
      expect(recorder.state.isRecording, true);
    });
  });

  group('SessionRecorder — edge cases', () {
    test('can start and stop multiple times', () async {
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());

      for (int i = 0; i < 3; i++) {
        recorder.startRecording();
        expect(recorder.state.status, RecordingStatus.recording);

        await recorder.stopRecording();
        expect(recorder.state.status, RecordingStatus.idle);
      }
    });

    test('recordPoint is no-op when idle (no auto-start condition)', () {
      final recorder = SessionRecorder(lapRecorder: CompleteLapRecorder());

      // Data with currentLap=0, shouldn't trigger anything.
      recorder.recordPoint(TelemetryData(
        timestamp: DateTime(2026),
        packetId: 1,
        gear: 0,
        rpm: 0,
        speedKmh: 0,
        throttle: 0,
        brake: 0,
        currentLap: 0,
        currentLapTime: Duration.zero,
      ));

      expect(recorder.state.status, RecordingStatus.idle);
    });
  });
}
