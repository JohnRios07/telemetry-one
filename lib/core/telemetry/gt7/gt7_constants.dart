/// GT7 protocol constants — offsets, keys, and magic numbers.
///
/// Based on community research:
/// - Nenkai/PDTools (C#)
/// - MacManley/gt7-udp (C++)
/// - snipem/gt7dashboard (Python)
class Gt7Constants {
  Gt7Constants._();

  // Salsa20
  static const String salsa20Key = 'Simulator Interface Packet GT7 ver 0.0';
  static const int ivOffset = 0x40;
  static final int ivXorConstant = 0xDEADBEAF;
  static const int salsaDataOffset = 0x28;

  // Packet validation
  static final int magicNumber = 0x47375330; // "G7S0"
  static const int magicOffset = 0x00;

  // Packet A size
  static const int packetASize = 296;

  // Field offsets (Packet A)
  static const int offsetPosition = 0x04; // float[3]
  static const int offsetVelocity = 0x10; // float[3]
  static const int offsetRpm = 0x3C; // float
  static const int offsetCurrentFuel = 0x44; // float (liters)
  static const int offsetFuelCapacity = 0x48; // float (liters)
  static const int offsetCarSpeed = 0x4C; // float (m/s)
  static const int offsetBoost = 0x50; // float
  static const int offsetOilPressure = 0x54; // float
  static const int offsetTyreTemp = 0x60; // float[4]
  static const int offsetPackageId = 0x70; // int32
  static const int offsetCurrentLap = 0x74; // int16 lap count (not lap time)
  static const int offsetTotalLaps = 0x76; // int16
  static const int offsetBestLap = 0x78; // int32 (ms)
  static const int offsetLastLap = 0x7C; // int32 (ms)
  static const int offsetCurrentPosition = 0x84; // int16
  static const int offsetRpmRevWarning = 0x88; // uint16
  static const int offsetRpmRevLimiter = 0x8A; // uint16
  static const int offsetSimulatorFlags = 0x8E; // uint8
  static const int offsetGears = 0x90; // uint8 (lower 4 = current, upper 4 = suggested)
  static const int offsetThrottle = 0x91; // uint8 (0-255)
  static const int offsetBrake = 0x92; // uint8 (0-255)
  static const int offsetClutch = 0xF4; // float
  static const int offsetCarId = 0x124; // int32
}
