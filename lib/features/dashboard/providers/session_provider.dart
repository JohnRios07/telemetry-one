import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../core/storage/session_model.dart';
import '../../../core/storage/session_repository.dart';

/// Manages session recording state.
///
/// When recording, telemetry points are buffered and periodically
/// flushed to Hive storage.
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

  SessionRecorder() : super(const SessionState());

  /// Start recording telemetry data to a new session.
  void startRecording() {
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
      final finalSession = Session(
        id: state.currentSession!.id,
        startTime: state.currentSession!.startTime,
        endTime: DateTime.now(),
        game: state.currentSession!.game,
        points: _bufferedPoints,
      );

      await _repository.saveSession(finalSession);
      _bufferedPoints.clear();
      state = const SessionState(status: RecordingStatus.idle);
    } catch (e) {
      state = SessionState(
        status: RecordingStatus.idle,
        error: 'Failed to save session: $e',
      );
    }
  }

  // Simple in-memory buffer for recording
  final List<TelemetryPoint> _bufferedPoints = [];

  /// Called from the telemetry stream to buffer a data point.
  void recordPoint(TelemetryData data) {
    if (!state.isRecording) return;
    _bufferedPoints.add(TelemetryPoint(
      timestamp: data.timestamp,
      speedKmh: data.speedKmh,
      rpm: data.rpm,
      gear: data.gear,
      throttle: data.throttle,
      brake: data.brake,
    ));
  }
}
