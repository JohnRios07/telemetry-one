import '../models/telemetry_data.dart';
import '../storage/session_model.dart';

/// Pure state machine that records only laps completed after a clean lap start.
class CompleteLapRecorder {
  static const Duration _cleanLapStartThreshold = Duration(seconds: 2);
  static const Duration _strongLapTimeRewindThreshold = Duration(seconds: 2);

  final List<CompleteLap> _completedLaps = [];
  _CandidateLap? _candidate;
  int? _lastPacketId;

  List<CompleteLap> get completedLaps => List.unmodifiable(_completedLaps);

  void reset() {
    _completedLaps.clear();
    _candidate = null;
    _lastPacketId = null;
  }

  void ingest(TelemetryData data) {
    if (_isDuplicatePacket(data)) return;

    if (_isPacketRewind(data)) {
      _rearmAfter(data);
      return;
    }

    final candidate = _candidate;
    if (candidate == null) {
      _lastPacketId = data.packetId;
      // Create a candidate whenever we see a positive lap number,
      // even if currentLapTime is null or already > 2s. Without this
      // the first lap is permanently lost when auto-start triggers
      // mid-lap, and auto-stop (which depends on completed laps)
      // never fires.
      if (data.currentLap > 0) {
        _startCandidate(data);
      }
      return;
    }

    if (_shouldInvalidateCandidate(candidate, data)) {
      _rearmAfter(data);
      return;
    }

    if (_isLapTransition(candidate, data)) {
      _completeCandidate(candidate, data);
      _lastPacketId = data.packetId;

      if (_isCleanLapStart(data)) {
        _startCandidate(data);
      } else {
        _candidate = null;
      }
      return;
    }

    _lastPacketId = data.packetId;
    candidate.add(data);
  }

  bool _isDuplicatePacket(TelemetryData data) {
    return _lastPacketId == data.packetId;
  }

  bool _isPacketRewind(TelemetryData data) {
    final lastPacketId = _lastPacketId;
    return lastPacketId != null && data.packetId < lastPacketId;
  }

  bool _isCleanLapStart(TelemetryData data) {
    final currentLapTime = data.currentLapTime;
    return data.currentLap > 0 &&
        currentLapTime != null &&
        currentLapTime <= _cleanLapStartThreshold;
  }

  void _startCandidate(TelemetryData data) {
    _candidate = _CandidateLap(
      lapNumber: data.currentLap,
      startTime: data.timestamp,
    )..add(data);
  }

  bool _shouldInvalidateCandidate(_CandidateLap candidate, TelemetryData data) {
    if (data.currentLap < candidate.lapNumber) return true;
    if (data.currentLap > candidate.lapNumber + 1) return true;

    final previousLapTime = candidate.lastCurrentLapTime;
    final currentLapTime = data.currentLapTime;
    if (data.currentLap == candidate.lapNumber &&
        previousLapTime != null &&
        currentLapTime != null &&
        previousLapTime - currentLapTime >= _strongLapTimeRewindThreshold) {
      return true;
    }

    return false;
  }

  bool _isLapTransition(_CandidateLap candidate, TelemetryData data) {
    return data.currentLap == candidate.lapNumber + 1;
  }

  void _completeCandidate(_CandidateLap candidate, TelemetryData data) {
    if (candidate.lapNumber == 0) {
      _candidate = null;
      return;
    }

    final officialLapTime =
        data.lastLapTime ?? data.timestamp.difference(candidate.startTime);

    _completedLaps.add(
      CompleteLap(
        id: '${candidate.lapNumber}-${candidate.startTime.microsecondsSinceEpoch}',
        lapNumber: candidate.lapNumber,
        startTime: candidate.startTime,
        endTime: data.timestamp,
        officialLapTime: officialLapTime,
        bestLapTimeAtCompletion: data.bestLapTime,
        position: data.currentPosition > 0 ? data.currentPosition : null,
        points: List.unmodifiable(candidate.points),
      ),
    );
    _candidate = null;
  }

  void _rearmAfter(TelemetryData data) {
    _candidate = null;
    _lastPacketId = data.packetId;
  }
}

class _CandidateLap {
  final int lapNumber;
  final DateTime startTime;
  final List<TelemetryPoint> points = [];
  Duration? lastCurrentLapTime;

  _CandidateLap({required this.lapNumber, required this.startTime});

  void add(TelemetryData data) {
    points.add(_pointFrom(data));
    lastCurrentLapTime = data.currentLapTime;
  }

  TelemetryPoint _pointFrom(TelemetryData data) {
    return TelemetryPoint(
      timestamp: data.timestamp,
      packetId: data.packetId,
      currentLap: data.currentLap,
      currentLapTime: data.currentLapTime,
      speedKmh: data.speedKmh,
      rpm: data.rpm,
      gear: data.gear,
      throttle: data.throttle,
      brake: data.brake,
      clutch: data.clutch,
      fuelCurrentL: data.fuelCurrentL,
      fuelCapacityL: data.fuelCapacityL,
      tireTemps: data.tireTemps,
      posX: data.posX,
      posY: data.posY,
      posZ: data.posZ,
    );
  }
}
