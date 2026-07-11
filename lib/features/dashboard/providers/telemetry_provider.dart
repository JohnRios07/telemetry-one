import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/telemetry_data.dart';
import '../../../core/network/udp_service.dart';
import '../../../core/telemetry/gt7/gt7_parser.dart';
import 'telemetry_buffer.dart';

/// Singleton instance of the UDP service.
final udpServiceProvider = Provider<UdpService>((ref) {
  final service = UdpService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Stream of parsed telemetry data from the GT7 UDP stream.
///
/// No throttling — data flows at native 60Hz for maximum responsiveness.
final telemetryStreamProvider = StreamProvider<TelemetryData>((ref) {
  final udpService = ref.watch(udpServiceProvider);
  final parser = Gt7Parser();

  return udpService.packetStream
      .map((bytes) => parser.parse(bytes))
      .where((data) => data != null)
      .map((data) => data!);
});

/// Current telemetry data (last value or null).
final telemetryDataProvider = Provider<TelemetryData?>((ref) {
  return ref.watch(telemetryStreamProvider).valueOrNull;
});

/// Connection state stream from the UDP service.
final connectionStateProvider = StreamProvider<UdpConnectionState>((ref) {
  final udpService = ref.watch(udpServiceProvider);
  return udpService.stateStream;
});

/// Error messages from the UDP service.
final connectionErrorProvider = StreamProvider<String>((ref) {
  final udpService = ref.watch(udpServiceProvider);
  return udpService.errorStream;
});

// ─── Telemetry graph buffer ──────────────────────────────────────

final telemetryBufferProvider =
    StateNotifierProvider<TelemetryBufferNotifier, TelemetryBuffer>((ref) {
      final notifier = TelemetryBufferNotifier();
      ref.onDispose(() => notifier.dispose());
      return notifier;
    });

class TelemetryBufferNotifier extends StateNotifier<TelemetryBuffer> {
  TelemetryBufferNotifier() : super(TelemetryBuffer());

  void add(double throttle, double brake) {
    final nextState = state.copy();
    nextState.add(throttle, brake);
    state = nextState;
  }

  void clear() {
    final nextState = state.copy();
    nextState.clear();
    state = nextState;
  }
}

// --- Individual field selectors for efficient widget rebuilds ---

final currentRpmProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.rpm ?? 0;
});

final currentSpeedProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.speedKmh ?? 0;
});

final currentGearProvider = Provider<int>((ref) {
  return ref.watch(telemetryDataProvider)?.gear ?? 0;
});

final currentThrottleProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.throttle ?? 0;
});

final currentBrakeProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.brake ?? 0;
});

final currentFuelProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.fuelPercent ?? 0;
});

final currentFuelProviderRaw = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.fuelCurrentL ?? 0;
});

final fuelCapacityProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.fuelCapacityL ?? 0;
});

final tireTempsProvider = Provider<List<double>>((ref) {
  return ref.watch(telemetryDataProvider)?.tireTemps ?? [0, 0, 0, 0];
});

final tirePressuresProvider = Provider<List<double>?>((ref) {
  return ref.watch(telemetryDataProvider)?.tirePressures;
});

final currentPositionProvider = Provider<int>((ref) {
  return ref.watch(telemetryDataProvider)?.currentPosition ?? 0;
});

final rpmRatioProvider = Provider<double>((ref) {
  final data = ref.watch(telemetryDataProvider);
  if (data == null) return 0;
  return data.rpmRatio;
});

final revLimiterProvider = Provider<double>((ref) {
  return ref.watch(telemetryDataProvider)?.rpmRevLimiter ?? 0;
});

final suggestedGearProvider = Provider<int>((ref) {
  return ref.watch(telemetryDataProvider)?.suggestedGear ?? 0;
});

final carPositionProvider = Provider<({double x, double y, double z})>((ref) {
  final data = ref.watch(telemetryDataProvider);
  if (data == null) return (x: 0, y: 0, z: 0);
  return (x: data.posX, y: data.posY, z: data.posZ);
});

final lapInfoProvider = Provider<_LapInfo>((ref) {
  final data = ref.watch(telemetryDataProvider);
  return _LapInfo(
    currentLap: data?.currentLap ?? 0,
    totalLaps: data?.totalLaps ?? 0,
    lastLapTime: data?.lastLapTime,
    bestLapTime: data?.bestLapTime,
    currentLapTime: data?.currentLapTime,
  );
});

class _LapInfo {
  final int currentLap;
  final int totalLaps;
  final Duration? lastLapTime;
  final Duration? bestLapTime;
  final Duration? currentLapTime;

  const _LapInfo({
    this.currentLap = 0,
    this.totalLaps = 0,
    this.lastLapTime,
    this.bestLapTime,
    this.currentLapTime,
  });

  Duration? get deltaTime {
    if (bestLapTime == null || currentLapTime == null) return null;
    return currentLapTime! - bestLapTime!;
  }
}

/// Rev limiter info for gauge rendering.
final revInfoProvider = Provider<_RevInfo>((ref) {
  final data = ref.watch(telemetryDataProvider);
  return _RevInfo(
    rpm: data?.rpm ?? 0,
    revWarning: data?.rpmRevWarning ?? 0,
    revLimiter: data?.rpmRevLimiter ?? 0,
  );
});

class _RevInfo {
  final double rpm;
  final double revWarning;
  final double revLimiter;

  const _RevInfo({this.rpm = 0, this.revWarning = 0, this.revLimiter = 0});

  double get ratio => revLimiter > 0 ? (rpm / revLimiter).clamp(0.0, 1.0) : 0.0;
}
