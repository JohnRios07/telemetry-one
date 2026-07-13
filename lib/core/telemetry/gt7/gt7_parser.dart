import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import '../../models/telemetry_data.dart';
import '../telemetry_parser.dart';
import 'gt7_constants.dart';
import 'gt7_packet.dart';

/// GT7-specific telemetry parser with Salsa20 decryption.
///
/// Decrypts the 368-byte Packet C using Salsa20, validates the magic
/// number (0x47375330 = "G7S0"), and maps fields to [TelemetryData].
class Gt7Parser extends TelemetryParser {
  final Salsa20Engine _salsa20 = Salsa20Engine();
  final Uint8List _key;

  Gt7Parser()
      : _key = Uint8List.fromList(
          Gt7Constants.salsa20Key.codeUnits.take(32).toList(),
        );

  /// Decrypt a raw GT7 Packet C and parse into [TelemetryData].
  ///
  /// Returns `null` if the packet is invalid (wrong size, bad magic).
  @override
  TelemetryData? parse(Uint8List bytes) {
    try {
      debugPrint('[GT7] Raw packet: ${bytes.length} bytes, '
          'magic bytes: ${bytes.sublist(0, 4).map((b) => b.toRadixString(16)).join(" ")}');

      final decrypted = _decrypt(bytes);
      debugPrint('[GT7] Decrypted length: ${decrypted.length} bytes');

      final packet = Gt7Packet.fromDecryptedBytes(decrypted);

      final actualMagic = packet.magic.toRadixString(16);
      final expectedMagic = Gt7Constants.magicNumber.toRadixString(16);
      debugPrint('[GT7] Magic: 0x$actualMagic vs 0x$expectedMagic');

      if (packet.magic != Gt7Constants.magicNumber) {
        debugPrint('[GT7] ❌ Magic mismatch — dropping packet');
        return null; // Invalid packet
      }

      debugPrint('[GT7] ✅ Parsed: speed=${packet.speedKmh.toStringAsFixed(1)} '
          'rpm=${packet.rpm.toStringAsFixed(0)} gear=${packet.currentGear}');
      return _toTelemetryData(packet);
    } catch (e, stack) {
      debugPrint('[GT7] ❌ Parse error: $e\n$stack');
      return null; // Silently discard malformed packets
    }
  }

  /// Salsa20 decryption with custom IV generation.
  ///
  /// IV extraction: bytes at offset 0x40 → uint32 LE (iv1)
  /// iv2 = iv1 XOR 0xDEADBEEF for Packet C ('C' heartbeat)
  /// Nonce = [iv2 LE][iv1 LE] (8 bytes)
  /// The ENTIRE packet is encrypted with Salsa20 (including the magic at offset 0).
  Uint8List _decrypt(Uint8List encrypted) {
    // Extract IV from raw (encrypted) bytes at offset 0x40
    final iv1 = ByteData.sublistView(encrypted, Gt7Constants.ivOffset, Gt7Constants.ivOffset + 4)
        .getUint32(0, Endian.little);
    final iv2 = iv1 ^ Gt7Constants.packetCXorConstant;

    final nonce = Uint8List(8);
    final nonceView = ByteData.view(nonce.buffer, 0, 8);
    nonceView.setUint32(0, iv2, Endian.little);
    nonceView.setUint32(4, iv1, Endian.little);

    final params = ParametersWithIV(KeyParameter(_key), nonce);
    _salsa20.reset();
    _salsa20.init(false, params);

    // Decrypt the ENTIRE packet (the magic at offset 0 is also encrypted)
    final decrypted = Uint8List(encrypted.length);
    _salsa20.processBytes(encrypted, 0, encrypted.length, decrypted, 0);

    debugPrint('[GT7] Decrypted magic bytes: '
        '${decrypted.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(" ")}');

    return decrypted;
  }

  TelemetryData _toTelemetryData(Gt7Packet packet) {
    return TelemetryData(
      timestamp: DateTime.now(),
      packetId: packet.packetId,
      speedKmh: packet.speedKmh,
      rpm: packet.rpm,
      gear: packet.currentGear,
      throttle: packet.throttlePct,
      brake: packet.brakePct,
      clutch: packet.clutch,
      fuelPercent: packet.fuelPct,
      fuelCurrentL: packet.currentFuel,
      fuelCapacityL: packet.fuelCapacity,
      tireTemps: packet.tyreTemps,
      currentLap: packet.currentLap,
      totalLaps: packet.totalLaps,
      lastLapTime: packet.lastLapMs >= 0
          ? Duration(milliseconds: packet.lastLapMs)
          : null,
      bestLapTime: packet.bestLapMs >= 0
          ? Duration(milliseconds: packet.bestLapMs)
          : null,
      currentLapTime: packet.currentLapTimeMs >= 0
          ? Duration(milliseconds: packet.currentLapTimeMs)
          : null,
      currentPosition: packet.currentPosition,
      suggestedGear: packet.suggestedGear,
      steeringAngle: packet.steeringAngle,
      posX: packet.posX,
      posY: packet.posY,
      posZ: packet.posZ,
      rpmRevWarning: packet.rpmRevWarning.toDouble(),
      rpmRevLimiter: packet.rpmRevLimiter.toDouble(),
    );
  }
}
