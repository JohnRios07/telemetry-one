import 'dart:async';

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

/// Tracks auto-start/stop lifecycle for the current recording session.
class _AutoLifecycle {
  /// Whether [recordPoint] has already auto-started recording once.
  bool triggered = false;

  /// Whether the user explicitly called [stopRecording] while
  /// [_autoTriggered] was true — prevents re-trigger after manual stop
  /// within the same race.
  bool userStoppedAfterAutoStart = false;
}

class SessionRecorder extends StateNotifier<SessionState> {
  final SessionRepository _repository;
  final CompleteLapRecorder _lapRecorder;
  bool _isSaving = false;
  final _AutoLifecycle _auto = _AutoLifecycle();
  int? _lastObservedLap;
  Duration? _lastObservedLapTime;

  /// Timestamp of the most recent completed lap. Used to detect
  /// session end in practice mode (where [TelemetryData.totalLaps] is 0).
  DateTime? _lastLapCompletedAt;

  /// How long to wait after the last lap before auto-stopping
  /// when no total-lap count is available from the game.
  /// Set long enough to cover pit stops (60–90 s).
  static const Duration _lapTimeout = Duration(seconds: 120);

  SessionRecorder({
    SessionRepository? repository,
    CompleteLapRecorder? lapRecorder,
  })  : _repository = repository ?? SessionRepository(),
        _lapRecorder = lapRecorder ?? CompleteLapRecorder(),
        super(const SessionState());

  /// Start recording telemetry data to a new session.
  void startRecording() {
    _isSaving = false;
    _lapRecorder.reset();
    _lastLapCompletedAt = null;
    // Manual start resets auto-lifecycle so auto-start can work
    // for a fresh session.
    _auto.triggered = false;
    _auto.userStoppedAfterAutoStart = false;

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
    if (!state.isRecording || state.currentSession == null || _isSaving) return;

    // Remember the user chose to stop so auto-start won't re-trigger
    // on subsequent laps.
    if (_auto.triggered) {
      _auto.userStoppedAfterAutoStart = true;
    }

    // Capture snapshot BEFORE any async gap to avoid race conditions.
    _isSaving = true;
    final snapshot = state.currentSession!;

    state = SessionState(
      status: RecordingStatus.saving,
      currentSession: snapshot,
    );

    await _persist(snapshot);
  }

  /// Called from the telemetry stream to buffer a data point.
  void recordPoint(TelemetryData data) {
    final int previousLap = _lastObservedLap ?? 0;
    final bool inFirstLapStartWindow =
        data.currentLap == 1 &&
        data.currentLapTime != null &&
        data.currentLapTime! <= const Duration(seconds: 2) &&
        data.speedKmh > 0;
    final bool wasAlreadyInFirstLapStartWindow =
        previousLap == 1 &&
        _lastObservedLapTime != null &&
        _lastObservedLapTime! <= const Duration(seconds: 2);
    final bool cleanFirstLapStart =
        inFirstLapStartWindow && !wasAlreadyInFirstLapStartWindow;

    // Auto-start when the first race lap is detected.
    // Fires at most once per recording cycle; after a manual stop it
    // stays disabled until the next manual start or auto-stop.
    if (!state.isRecording &&
        !_isSaving &&
        !_auto.triggered &&
        !_auto.userStoppedAfterAutoStart) {
      if (cleanFirstLapStart) {
        startRecording();
        _auto.triggered = true; // Re-assert after startRecording clears it.
      } else {
        _lastObservedLap = data.currentLap;
        _lastObservedLapTime = data.currentLapTime;
        return;
      }
    }

    _lastObservedLap = data.currentLap;
    _lastObservedLapTime = data.currentLapTime;

    if (!state.isRecording) return;

    // Timeout-based auto-stop for practice mode (no set lap count).
    // If a lap was completed but no new lap arrives within the timeout
    // while the car is stationary, assume the session is over.
    if (_lastLapCompletedAt != null && data.speedKmh <= 1) {
      final Duration idle = DateTime.now().difference(_lastLapCompletedAt!);
      if (idle >= _lapTimeout) {
        _triggerAutoStop();
        return;
      }
    }

    final int beforeCount = _lapRecorder.completedLaps.length;
    _lapRecorder.ingest(data);

    if (data.totalLaps <= 0) return;

    final int afterCount = _lapRecorder.completedLaps.length;
    if (afterCount <= beforeCount) return;

    final CompleteLap justCompleted = _lapRecorder.completedLaps.last;
    _lastLapCompletedAt = DateTime.now();

    if (justCompleted.lapNumber >= data.totalLaps) {
      // Auto-stop on final lap — capture snapshot synchronously,
      // then persist asynchronously. The snapshot avoids the race
      // where state.currentSession could change during the save.
      _triggerAutoStop();
    }
  }

  /// Initiate the auto-stop sequence.
  ///
  /// Captures the session snapshot synchronously (before any async gap)
  /// and delegates persistence to [_persist].
  void _triggerAutoStop() {
    if (_isSaving) return;
    _isSaving = true;
    final snapshot = state.currentSession!;
    state = SessionState(
      status: RecordingStatus.saving,
      currentSession: snapshot,
    );
    unawaited(_persist(snapshot, fromAutoStop: true));
  }

  /// Persist a [snapshot] of session data to storage.
  ///
  /// [snapshot] must be captured before the first `await` to
  /// guarantee that the data being saved is internally consistent.
  ///
  /// When [fromAutoStop] is `true` the auto-lifecycle is reset so
  /// auto-start can work for the next race.
  Future<void> _persist(Session snapshot, {bool fromAutoStop = false}) async {
    try {
      final completedLaps = _lapRecorder.completedLaps;
      if (completedLaps.isEmpty) {
        _lapRecorder.reset();
        _isSaving = false;
        state = const SessionState(status: RecordingStatus.idle);
        return;
      }

      final completedPoints = completedLaps
          .expand<TelemetryPoint>((lap) => lap.points)
          .toList(growable: false);
      final finalSession = Session(
        id: snapshot.id,
        startTime: snapshot.startTime,
        endTime: DateTime.now(),
        game: snapshot.game,
        ps5Ip: snapshot.ps5Ip,
        points: completedPoints,
        laps: completedLaps,
      );

      await _repository.saveSession(finalSession);
      _lapRecorder.reset();
      _isSaving = false;

      if (fromAutoStop) {
        // Race ended naturally — reset so auto-start can work for the next one.
        _auto.triggered = false;
        _auto.userStoppedAfterAutoStart = false;
      }

      state = const SessionState(status: RecordingStatus.idle);
    } catch (e) {
      _lapRecorder.reset();
      _isSaving = false;
      state = SessionState(
        status: RecordingStatus.idle,
        error: 'Failed to save session: $e',
      );
    }
  }
}
