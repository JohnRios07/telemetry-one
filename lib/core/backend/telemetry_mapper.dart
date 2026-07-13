import '../models/telemetry_data.dart';
import 'telemetry_frame_dto.dart';

TelemetryFrameDto mapTelemetryToFrame(TelemetryData data) {
  final currentLapMs = data.currentLapTime != null
      ? data.currentLapTime!.inMilliseconds
      : 0;

  return TelemetryFrameDto(
    timestampUnixMs: data.timestamp.millisecondsSinceEpoch,
    speedMps: data.speedKmh / 3.6,
    rpm: data.rpm,
    gear: data.gear,
    throttle: data.throttle,
    brake: data.brake,
    steeringAngle: data.steeringAngle,
    fuelLiters: data.fuelCurrentL,
    positionX: data.posX,
    positionY: data.posY,
    positionZ: data.posZ,
    lapNumber: data.currentLap,
    currentLapMs: currentLapMs,
    lastLapMs: data.lastLapTime?.inMilliseconds,
    bestLapMs: data.bestLapTime?.inMilliseconds,
    isOnTrack: true,
  );
}

List<TelemetryFrameDto> mapTelemetryBatch(List<TelemetryData> batch) {
  return batch.map(mapTelemetryToFrame).toList(growable: false);
}

FrameBatchRequest buildBatchRequest(
  String sessionId,
  List<TelemetryData> batch,
) {
  return FrameBatchRequest(
    sessionId: sessionId,
    frames: mapTelemetryBatch(batch),
  );
}

int computeBatchSize({
  required int availableFrames,
  int defaultBatch = 120,
  int maxBatch = 600,
}) {
  if (availableFrames <= 0) return 0;
  return availableFrames.clamp(1, defaultBatch).clamp(1, maxBatch);
}
