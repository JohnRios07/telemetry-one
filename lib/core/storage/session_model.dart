// Session data models for telemetry recording.
//
// These models represent a recorded telemetry session stored in Hive.
// A [Session] contains a list of [TelemetryPoint]s captured during a driving session.

class TelemetryPoint {
  final DateTime timestamp;
  final int? packetId;
  final int? currentLap;
  final Duration? currentLapTime;
  final double speedKmh;
  final double rpm;
  final int gear;
  final double throttle;
  final double brake;
  final double? clutch;
  final double? fuelCurrentL;
  final double? fuelCapacityL;
  final List<double>? tireTemps;
  final double? posX;
  final double? posY;
  final double? posZ;

  const TelemetryPoint({
    required this.timestamp,
    this.packetId,
    this.currentLap,
    this.currentLapTime,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
    this.clutch,
    this.fuelCurrentL,
    this.fuelCapacityL,
    this.tireTemps,
    this.posX,
    this.posY,
    this.posZ,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'packet_id': packetId,
    'current_lap': currentLap,
    'current_lap_time_ms': currentLapTime?.inMilliseconds,
    'speed_kmh': speedKmh,
    'rpm': rpm,
    'gear': gear,
    'throttle': throttle,
    'brake': brake,
    'clutch': clutch,
    'fuel_current_l': fuelCurrentL,
    'fuel_capacity_l': fuelCapacityL,
    'tire_temps': tireTemps,
    'pos_x': posX,
    'pos_y': posY,
    'pos_z': posZ,
  };
}

class CompleteLap {
  final String id;
  final int lapNumber;
  final DateTime startTime;
  final DateTime endTime;
  final Duration officialLapTime;
  final Duration? bestLapTimeAtCompletion;
  final int? position;
  final bool? isOutLap;
  final bool? isPitLap;
  final List<TelemetryPoint> points;

  const CompleteLap({
    required this.id,
    required this.lapNumber,
    required this.startTime,
    required this.endTime,
    required this.officialLapTime,
    this.bestLapTimeAtCompletion,
    this.position,
    this.isOutLap,
    this.isPitLap,
    this.points = const [],
  });

  /// Whether this lap should be considered valid for engineer analysis.
  ///
  /// A lap is valid when it has a positive recorded time and is not
  /// flagged as an out-lap or pit-lap by the game protocol.
  bool get isValidForEngineer =>
      officialLapTime > Duration.zero &&
      isOutLap != true &&
      isPitLap != true;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lap_number': lapNumber,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'official_lap_time_ms': officialLapTime.inMilliseconds,
    'best_lap_time_at_completion_ms': bestLapTimeAtCompletion?.inMilliseconds,
    'position': position,
    'is_out_lap': isOutLap,
    'is_pit_lap': isPitLap,
    'points': points.map((p) => p.toJson()).toList(),
  };
}

class Session {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String game;
  final String? ps5Ip;
  final String? trackName;
  final List<TelemetryPoint> points;
  final List<CompleteLap> laps;

  const Session({
    required this.id,
    required this.startTime,
    this.endTime,
    this.game = 'GT7',
    this.ps5Ip,
    this.trackName,
    this.points = const [],
    this.laps = const [],
  });

  Duration? get duration {
    if (endTime == null) return null;
    return endTime!.difference(startTime);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime?.toIso8601String(),
    'game': game,
    'ps5_ip': ps5Ip,
    'track_name': trackName,
    'points': points.map((p) => p.toJson()).toList(),
    'laps': laps.map((lap) => lap.toJson()).toList(),
  };
}
