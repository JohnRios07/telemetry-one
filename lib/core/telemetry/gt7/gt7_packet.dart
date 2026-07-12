import 'dart:typed_data';
import 'gt7_constants.dart';

/// Raw GT7 Packet C parsed from decrypted bytes.
///
/// Packet C (0x170 / 368 bytes) is a superset of Packet ~ and Packet A for the
/// shared core telemetry block used by the dashboard. Derived getters provide
/// normalized values for the UI layer.
class Gt7Packet {
  final int magic;
  final double posX;
  final double posY;
  final double posZ;
  final double rpm;
  final double currentFuel;
  final double fuelCapacity;
  final double carSpeed;
  final List<double> tyreTemps;
  final int packetId;
  final int currentLap;
  final int totalLaps;
  final int bestLapMs;
  final int lastLapMs;
  final int currentLapTimeMs;
  final double steeringAngle;
  final int currentPosition;
  final int rpmRevWarning;
  final int rpmRevLimiter;
  final int simulatorFlags;
  final int gears;
  final int throttle;
  final int brake;
  final double clutch;

  const Gt7Packet({
    required this.magic,
    required this.posX,
    required this.posY,
    required this.posZ,
    required this.rpm,
    required this.currentFuel,
    required this.fuelCapacity,
    required this.carSpeed,
    required this.tyreTemps,
    required this.packetId,
    required this.currentLap,
    required this.totalLaps,
    required this.bestLapMs,
    required this.lastLapMs,
    required this.currentLapTimeMs,
    required this.steeringAngle,
    required this.currentPosition,
    required this.rpmRevWarning,
    required this.rpmRevLimiter,
    required this.simulatorFlags,
    required this.gears,
    required this.throttle,
    required this.brake,
    required this.clutch,
  });

  // --- Derived getters ---

  double get speedKmh => carSpeed * 3.6;
  double get throttlePct => throttle / 255.0;
  double get brakePct => brake / 255.0;
  double get fuelPct =>
      fuelCapacity > 0 ? (currentFuel / fuelCapacity * 100).clamp(0, 100) : 0.0;
  int get currentGear => gears & 0x0F;
  int get suggestedGear => gears >> 4;
  bool get isOnTrack => (simulatorFlags & 0x01) != 0;

  /// Parse a decrypted Packet C payload.
  static Gt7Packet fromDecryptedBytes(Uint8List data) {
    if (data.length < Gt7Constants.expectedPacketSize) {
      throw ArgumentError(
          'Packet too short: ${data.length} < ${Gt7Constants.expectedPacketSize}');
    }

    final buf = ByteData.sublistView(data);

    return Gt7Packet(
      magic: buf.getInt32(Gt7Constants.magicOffset, Endian.little),
      posX: buf.getFloat32(Gt7Constants.offsetPosition, Endian.little),
      posY: buf.getFloat32(Gt7Constants.offsetPosition + 4, Endian.little),
      posZ: buf.getFloat32(Gt7Constants.offsetPosition + 8, Endian.little),
      rpm: buf.getFloat32(Gt7Constants.offsetRpm, Endian.little),
      currentFuel:
          buf.getFloat32(Gt7Constants.offsetCurrentFuel, Endian.little),
      fuelCapacity:
          buf.getFloat32(Gt7Constants.offsetFuelCapacity, Endian.little),
      carSpeed: buf.getFloat32(Gt7Constants.offsetCarSpeed, Endian.little),
      tyreTemps: [
        buf.getFloat32(Gt7Constants.offsetTyreTemp, Endian.little),
        buf.getFloat32(Gt7Constants.offsetTyreTemp + 4, Endian.little),
        buf.getFloat32(Gt7Constants.offsetTyreTemp + 8, Endian.little),
        buf.getFloat32(Gt7Constants.offsetTyreTemp + 12, Endian.little),
      ],
      packetId: buf.getInt32(Gt7Constants.offsetPackageId, Endian.little),
      currentLap: buf.getInt16(Gt7Constants.offsetCurrentLap, Endian.little),
      totalLaps: buf.getInt16(Gt7Constants.offsetTotalLaps, Endian.little),
      bestLapMs: buf.getInt32(Gt7Constants.offsetBestLap, Endian.little),
      lastLapMs: buf.getInt32(Gt7Constants.offsetLastLap, Endian.little),
      currentLapTimeMs:
          buf.getInt32(Gt7Constants.offsetCurrentLapTime, Endian.little),
      steeringAngle:
          buf.getFloat32(Gt7Constants.offsetSteeringAngle, Endian.little),
      currentPosition:
          buf.getInt16(Gt7Constants.offsetCurrentPosition, Endian.little),
      rpmRevWarning:
          buf.getUint16(Gt7Constants.offsetRpmRevWarning, Endian.little),
      rpmRevLimiter:
          buf.getUint16(Gt7Constants.offsetRpmRevLimiter, Endian.little),
      simulatorFlags:
          buf.getUint8(Gt7Constants.offsetSimulatorFlags),
      gears: buf.getUint8(Gt7Constants.offsetGears),
      throttle: buf.getUint8(Gt7Constants.offsetThrottle),
      brake: buf.getUint8(Gt7Constants.offsetBrake),
      clutch: buf.getFloat32(Gt7Constants.offsetClutch, Endian.little),
    );
  }
}
