/// Clean domain model for telemetry data — parser-agnostic.
///
/// This is the single source of truth for dashboard state.
/// All game-specific parsers (GT7, F1, ACC) map their raw packets
/// into this model.
class TelemetryData {
  final DateTime timestamp;
  final int packetId;

  // Level 1 — Critical
  final double speedKmh;
  final double rpm;
  final int gear; // 0 = neutral, -1 = reverse, 1+ = forward
  final double throttle; // 0.0–1.0
  final double brake; // 0.0–1.0
  final double clutch; // 0.0–1.0

  // Level 2 — Performance
  final double fuelPercent;
  final double fuelCurrentL; // Current fuel in liters
  final double fuelCapacityL; // Fuel capacity in liters
  final List<double> tireTemps; // [FL, FR, RL, RR]
  final List<double>? tirePressures; // [FL, FR, RL, RR] in PSI
  final int currentLap;
  final int totalLaps;
  final Duration? lastLapTime;
  final Duration? bestLapTime;
  /// Real live lap time when provided by the source protocol.
  final Duration? currentLapTime;

  // Level 3 — Race
  final int currentPosition;
  final int suggestedGear;
  final double posX;
  final double posY;
  final double posZ;

  // Level 4 — Chassis
  final double steeringAngle; // -1.0 (left) to 1.0 (right), 0.0 = center

  // Engine limits
  final double rpmRevWarning;
  final double rpmRevLimiter;

  const TelemetryData({
    required this.timestamp,
    this.packetId = 0,
    this.speedKmh = 0,
    this.rpm = 0,
    this.gear = 0,
    this.throttle = 0,
    this.brake = 0,
    this.clutch = 0,
    this.fuelPercent = 0,
    this.fuelCurrentL = 0,
    this.fuelCapacityL = 0,
    this.tireTemps = const [0, 0, 0, 0],
    this.tirePressures,
    this.currentLap = 0,
    this.totalLaps = 0,
    this.lastLapTime,
    this.bestLapTime,
    this.currentLapTime,
    this.currentPosition = 0,
    this.suggestedGear = 0,
    this.posX = 0,
    this.posY = 0,
    this.posZ = 0,
    this.steeringAngle = 0,
    this.rpmRevWarning = 0,
    this.rpmRevLimiter = 0,
  });

  /// Whether the engine is at or above the rev limiter.
  bool get isAtRevLimiter => rpmRevLimiter > 0 && rpm >= rpmRevLimiter;

  /// Whether the engine is in the warning zone (between warning and limiter).
  bool get isInWarningZone =>
      rpmRevWarning > 0 && rpm >= rpmRevWarning && rpm < rpmRevLimiter;

  /// Normalized RPM ratio (0.0–1.0) for gauge rendering.
  double get rpmRatio =>
      rpmRevLimiter > 0 ? (rpm / rpmRevLimiter).clamp(0.0, 1.0) : 0.0;

  @override
  String toString() =>
      'TelemetryData(packetId: $packetId, speed: ${speedKmh.toStringAsFixed(0)} km/h, '
      'gear: $gear, rpm: ${rpm.toStringAsFixed(0)}, '
      'fuel: ${fuelPercent.toStringAsFixed(0)}%)';
}
