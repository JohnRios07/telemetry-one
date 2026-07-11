import 'dart:typed_data';
import '../models/telemetry_data.dart';

/// Abstract interface for game-specific telemetry parsers.
///
/// Each supported game (GT7, F1, ACC) implements this interface
/// to decode its proprietary binary protocol.
abstract class TelemetryParser {
  /// Parse raw UDP bytes into a [TelemetryData] domain model.
  TelemetryData? parse(Uint8List bytes);
}
