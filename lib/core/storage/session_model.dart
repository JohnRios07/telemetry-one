// Session data models for telemetry recording.
//
// These models represent a recorded telemetry session stored in Hive.
// A [Session] contains a list of [TelemetryPoint]s captured during a driving session.

class TelemetryPoint {
  final DateTime timestamp;
  final double speedKmh;
  final double rpm;
  final int gear;
  final double throttle;
  final double brake;

  const TelemetryPoint({
    required this.timestamp,
    required this.speedKmh,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'speed_kmh': speedKmh,
        'rpm': rpm,
        'gear': gear,
        'throttle': throttle,
        'brake': brake,
      };
}

class Session {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String game;
  final String? ps5Ip;
  final List<TelemetryPoint> points;

  const Session({
    required this.id,
    required this.startTime,
    this.endTime,
    this.game = 'GT7',
    this.ps5Ip,
    this.points = const [],
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
        'points': points.map((p) => p.toJson()).toList(),
      };
}
