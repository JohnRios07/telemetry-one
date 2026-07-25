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

  /// Whether the caller explicitly invoked [stopRecording] while
  /// auto-start was active — prevents re-trigger after an explicit stop
  /// within the same race.
  bool userStoppedAfterAutoStart = false;
}

class SessionRecorder extends StateNotifier<SessionState> {
  final SessionRepository _repository;
  final CompleteLapRecorder _lapRecorder;
  bool _isSaving = false;
  final _AutoLifecycle _auto = _AutoLifecycle();
  int? _lastObservedPacketId;
  int? _lastObservedLap;
  Duration? _lastObservedLapTime;
  /// Blocks auto-start after a packet rewind until telemetry leaves the
  /// replayed lap-1 window and looks fresh again.
  bool _suppressAutoStartUntilFreshTelemetry = false;

  /// Timestamp of the most recent completed lap. Used to detect
  /// session end in practice mode (where [TelemetryData.totalLaps] is 0).
  DateTime? _lastLapCompletedAt;

  /// How long to wait after the last lap before auto-stopping
  /// when no total-lap count is available from the game.
  /// Set long enough to cover pit stops (60–90 s).
  static const Duration _lapTimeout = Duration(seconds: 120);
  static const Duration _nearZeroLapTimeThreshold = Duration(seconds: 2);
  static const double _minimumAutoStartSpeedKmh = 1;

  SessionRecorder({
    SessionRepository? repository,
    CompleteLapRecorder? lapRecorder,
  })  : _repository = repository ?? SessionRepository(),
        _lapRecorder = lapRecorder ?? CompleteLapRecorder(),
        super(const SessionState());

  /// Start recording telemetry data to a new session.
  void startRecording() {
    if (state.isRecording || _isSaving) return;

    _isSaving = false;
    _lapRecorder.reset();
    _lastLapCompletedAt = null;
    // A fresh session clears the auto-lifecycle so auto-start can work
    // again after a completed or manually stopped recording.
    _auto.triggered = false;
    _auto.userStoppedAfterAutoStart = false;
    _suppressAutoStartUntilFreshTelemetry = false;
    _resetTelemetryObservation();

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

    // Remember the explicit stop so auto-start won't re-trigger on
    // subsequent laps in the same race.
    if (_auto.triggered) {
      _auto.userStoppedAfterAutoStart = true;
    }

    _resetTelemetryObservation();

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
    _updateRewindSuppression(data);

    if (_isSaving) return;

    // Auto-start when the first race lap is detected.
    // Fires at most once per recording cycle; after a manual stop it
    // stays disabled until the next explicit start or auto-stop.
    if (!state.isRecording) {
      if (!_shouldAutoStart(data)) {
        _markTelemetryObservation(data);
        return;
      }

      startRecording();
      _auto.triggered = true; // Re-assert after startRecording clears it.
    }

    _markTelemetryObservation(data);

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

  bool _shouldAutoStart(TelemetryData data) {
    if (state.isRecording || _isSaving) return false;
    if (_auto.triggered || _auto.userStoppedAfterAutoStart) return false;

    if (!_isValidAutoStartTelemetry(data)) {
      return false;
    }

    final lastPacketId = _lastObservedPacketId;
    if (_suppressAutoStartUntilFreshTelemetry) {
      if (data.packetId > 0) {
        if (lastPacketId == null || data.packetId <= lastPacketId) {
          return false;
        }

        final currentLapTime = data.currentLapTime;
        if (currentLapTime == null || currentLapTime > _nearZeroLapTimeThreshold) {
          return false;
        }

        _suppressAutoStartUntilFreshTelemetry = false;
      } else {
        final currentLapTime = data.currentLapTime;
        final previousLapTime = _lastObservedLapTime;

        if (currentLapTime == null ||
            previousLapTime == null ||
            currentLapTime <= previousLapTime ||
            currentLapTime <= _nearZeroLapTimeThreshold) {
          return false;
        }

        _suppressAutoStartUntilFreshTelemetry = false;
      }
    }

    if (data.packetId <= 0) {
      return true;
    }

    if (lastPacketId == null) return true;
    if (data.packetId > lastPacketId) return true;
    if (data.packetId == lastPacketId) return false;

    final previousLap = _lastObservedLap;
    final previousLapTime = _lastObservedLapTime;
    final previousWasCleanStartWindow =
        previousLap == 1 &&
        previousLapTime != null &&
        previousLapTime <= _nearZeroLapTimeThreshold;

    return !previousWasCleanStartWindow;
  }

  bool _isValidAutoStartTelemetry(TelemetryData data) {
    if (data.currentLap != 1) return false;

    return data.isOnTrack && data.speedKmh > _minimumAutoStartSpeedKmh;
  }

  void _updateRewindSuppression(TelemetryData data) {
    if (data.packetId <= 0) return;

    final lastPacketId = _lastObservedPacketId;
    if (lastPacketId != null && data.packetId < lastPacketId) {
      _suppressAutoStartUntilFreshTelemetry = true;
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
        _resetTelemetryObservation();
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
      _resetTelemetryObservation();

      if (fromAutoStop) {
        // Race ended naturally — reset auto-lifecycle, but keep rewind
        // suppression until telemetry becomes fresh again.
        _auto.triggered = false;
        _auto.userStoppedAfterAutoStart = false;
      }

      state = const SessionState(status: RecordingStatus.idle);
    } catch (e) {
      _lapRecorder.reset();
      _isSaving = false;
      _resetTelemetryObservation();
      state = SessionState(
        status: RecordingStatus.idle,
        error: 'Failed to save session: $e',
      );
    }
  }

  void _resetTelemetryObservation() {
    _lastObservedPacketId = null;
    _lastObservedLap = null;
    _lastObservedLapTime = null;
  }

  void _markTelemetryObservation(TelemetryData data) {
    if (data.packetId > 0) {
      _lastObservedPacketId = data.packetId;
    }
    _lastObservedLap = data.currentLap;
    _lastObservedLapTime = data.currentLapTime;
  }
}
