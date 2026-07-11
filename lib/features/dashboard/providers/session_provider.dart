import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/telemetry_data.dart';
import '../../../core/recording/complete_lap_recorder.dart';
import '../../../core/storage/session_model.dart';
import '../../../core/storage/session_repository.dart';

/// Manages session recording state.
///
/// When recording, completed laps are persisted when recording stops.
final sessionRecorderProvider =
    StateNotifierProvider<SessionRecorder, SessionState>((ref) {
  return SessionRecorder();
});

/// Current session recording state.
enum RecordingStatus { idle, recording, saving }

class SessionState {
  final RecordingStatus status;
  final Session? currentSession;
  final String? error;

  const SessionState({
    this.status = RecordingStatus.idle,
    this.currentSession,
    this.error,
  });

  bool get isRecording => status == RecordingStatus.recording;
}

class SessionRecorder extends StateNotifier<SessionState> {
  final SessionRepository _repository = SessionRepository();
  final CompleteLapRecorder _lapRecorder = CompleteLapRecorder();

  SessionRecorder() : super(const SessionState());

  /// Start recording telemetry data to a new session.
  void startRecording() {
    _lapRecorder.reset();

    final session = Session(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      game: 'GT7',
    );

    state = SessionState(
      status: RecordingStatus.recording,
      currentSession: session,
    );
  }

  /// Stop recording and persist the session.
  Future<void> stopRecording() async {
    if (!state.isRecording || state.currentSession == null) return;

    state = SessionState(
      status: RecordingStatus.saving,
      currentSession: state.currentSession,
    );

    try {
      final completedLaps = _lapRecorder.completedLaps;
      final completedPoints = completedLaps
          .expand<TelemetryPoint>((lap) => lap.points)
          .toList(growable: false);
      final finalSession = Session(
        id: state.currentSession!.id,
        startTime: state.currentSession!.startTime,
        endTime: DateTime.now(),
        game: state.currentSession!.game,
        ps5Ip: state.currentSession!.ps5Ip,
        points: completedPoints,
        laps: completedLaps,
      );

      await _repository.saveSession(finalSession);
      _lapRecorder.reset();
      state = const SessionState(status: RecordingStatus.idle);
    } catch (e) {
      _lapRecorder.reset();
      state = SessionState(
        status: RecordingStatus.idle,
        error: 'Failed to save session: $e',
      );
    }
  }

  /// Called from the telemetry stream to buffer a data point.
  void recordPoint(TelemetryData data) {
    if (!state.isRecording) return;
    _lapRecorder.ingest(data);
  }
}
