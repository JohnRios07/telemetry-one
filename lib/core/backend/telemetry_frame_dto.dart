import 'dart:convert';

import 'track_capabilities_dto.dart';

Map<String, dynamic> _responsePayload(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    return data;
  }
  return json;
}

class TelemetryFrameDto {
  final int timestampUnixMs;
  final double speedMps;
  final double rpm;
  final int gear;
  final double throttle;
  final double brake;
  final double steeringAngle;
  final double fuelLiters;
  final double positionX;
  final double positionY;
  final double positionZ;
  final int lapNumber;
  final int currentLapMs;
  final int? lastLapMs;
  final int? bestLapMs;
  final bool isOnTrack;
  final double? yawRadians;
  final double? yawRate;
  final double? wheelSpeedFL;
  final double? wheelSpeedFR;
  final double? wheelSpeedRL;
  final double? wheelSpeedRR;

  const TelemetryFrameDto({
    required this.timestampUnixMs,
    required this.speedMps,
    required this.rpm,
    required this.gear,
    required this.throttle,
    required this.brake,
    required this.steeringAngle,
    required this.fuelLiters,
    required this.positionX,
    required this.positionY,
    required this.positionZ,
    required this.lapNumber,
    required this.currentLapMs,
    this.lastLapMs,
    this.bestLapMs,
    this.isOnTrack = false,
    this.yawRadians,
    this.yawRate,
    this.wheelSpeedFL,
    this.wheelSpeedFR,
    this.wheelSpeedRL,
    this.wheelSpeedRR,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'timestampUnixMs': timestampUnixMs,
      'speedMps': speedMps,
      'rpm': rpm,
      'gear': gear,
      'throttle': throttle,
      'brake': brake,
      'steering': steeringAngle,
      'fuelLiters': fuelLiters,
      'positionX': positionX,
      'positionY': positionY,
      'positionZ': positionZ,
      'lapNumber': lapNumber,
      'currentLapMs': currentLapMs,
      'isOnTrack': isOnTrack,
    };
    if (lastLapMs != null) json['lastLapMs'] = lastLapMs;
    if (bestLapMs != null) json['bestLapMs'] = bestLapMs;
    if (yawRadians != null) json['yawRadians'] = yawRadians;
    if (yawRate != null) json['yawRate'] = yawRate;
    if (wheelSpeedFL != null) json['wheelSpeedFL'] = wheelSpeedFL;
    if (wheelSpeedFR != null) json['wheelSpeedFR'] = wheelSpeedFR;
    if (wheelSpeedRL != null) json['wheelSpeedRL'] = wheelSpeedRL;
    if (wheelSpeedRR != null) json['wheelSpeedRR'] = wheelSpeedRR;
    return json;
  }
}

class FrameBatchRequest {
  final String sessionId;
  final List<TelemetryFrameDto> frames;

  const FrameBatchRequest({required this.sessionId, required this.frames});

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'frames': frames.map((f) => f.toJson()).toList(),
  };
}

class RejectionReasonCount {
  final String code;
  final int count;

  const RejectionReasonCount({required this.code, required this.count});

  factory RejectionReasonCount.fromJson(Map<String, dynamic> json) {
    return RejectionReasonCount(
      code: json['code'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}

class RejectionSummary {
  final List<RejectionReasonCount> reasons;

  String? get topReasonCode => reasons.isNotEmpty ? reasons.first.code : null;

  const RejectionSummary({required this.reasons});

  factory RejectionSummary.fromJson(Map<String, dynamic> json) {
    final reasonsList =
        (json['reasons'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
    return RejectionSummary(
      reasons: reasonsList.map(RejectionReasonCount.fromJson).toList(),
    );
  }
}

class IngestResponse {
  final String sessionId;
  final int receivedFrames;
  final int acceptedFrames;
  final int rejectedFrames;
  final int acceptedFromUnixMs;
  final int acceptedToUnixMs;
  final String status;
  final RejectionSummary? rejectionSummary;

  const IngestResponse({
    required this.sessionId,
    required this.receivedFrames,
    required this.acceptedFrames,
    required this.rejectedFrames,
    required this.acceptedFromUnixMs,
    required this.acceptedToUnixMs,
    required this.status,
    this.rejectionSummary,
  });

  bool get isAccepted => status == 'accepted';
  bool get hasRejections => rejectedFrames > 0 && rejectionSummary != null;
  String? get topRejectionCode => rejectionSummary?.topReasonCode;

  factory IngestResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    return IngestResponse(
      sessionId: payload['sessionId'] as String,
      receivedFrames: (payload['receivedFrames'] as num).toInt(),
      acceptedFrames: (payload['acceptedFrames'] as num).toInt(),
      rejectedFrames: (payload['rejectedFrames'] as num).toInt(),
      acceptedFromUnixMs: (payload['acceptedFromUnixMs'] as num).toInt(),
      acceptedToUnixMs: (payload['acceptedToUnixMs'] as num).toInt(),
      status: payload['status'] as String,
      rejectionSummary: payload['rejectionSummary'] != null
          ? RejectionSummary.fromJson(
              payload['rejectionSummary'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class IngestRejection {
  final String rejectionCode;
  final String category;
  final String? field;
  final int? frameIndex;

  const IngestRejection({
    required this.rejectionCode,
    required this.category,
    this.field,
    this.frameIndex,
  });

  bool get isBatchCategory => category == 'batch';
  bool get isFrameCategory => category == 'frame';
  bool get isConsistencyCategory => category == 'consistency';
  bool get isRetryable {
    if (isBatchCategory) {
      return rejectionCode == 'batch_too_large' ||
          rejectionCode == 'frames_empty';
    }
    return false;
  }

  factory IngestRejection.fromJson(Map<String, dynamic> json) {
    return IngestRejection(
      rejectionCode: json['rejectionCode'] as String,
      category: json['category'] as String,
      field: json['field'] as String?,
      frameIndex: (json['frameIndex'] as num?)?.toInt(),
    );
  }
}

class BackendError {
  final String code;
  final String message;
  final IngestRejection? details;

  const BackendError({required this.code, required this.message, this.details});

  bool get isBadRequest => code == 'bad_request';
  bool get isNotImplemented => code == 'not_implemented';
  bool get isInternalError => code == 'internal_error';
  bool get isSessionNotFound => code == 'session_not_found';
  bool get isSessionFinished => code == 'session_finished';
  bool get isRetryable =>
      code == 'internal_error' || code == 'service_unavailable';

  factory BackendError.fromJson(Map<String, dynamic> json) {
    final error = json['error'] as Map<String, dynamic>;
    return BackendError(
      code: error['code'] as String,
      message: error['message'] as String,
      details: error['details'] != null
          ? IngestRejection.fromJson(error['details'] as Map<String, dynamic>)
          : null,
    );
  }

  factory BackendError.parse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return BackendError.fromJson(json);
    } catch (_) {
      return BackendError(
        code: 'parse_error',
        message: 'Failed to parse error response',
      );
    }
  }
}

class TrackDetectionResponse {
  final String status;
  final String? trackId;
  final String? layoutId;
  final String? trackName;
  final String? layoutName;
  final double confidence;
  final List<String> reasons;
  final String? nextAction;
  final TrackCapabilitiesDto? capabilities;

  const TrackDetectionResponse({
    required this.status,
    this.trackId,
    this.layoutId,
    this.trackName,
    this.layoutName,
    this.confidence = 0,
    this.reasons = const [],
    this.nextAction,
    this.capabilities,
  });

  bool get isDetected => status == 'detected';
  bool get isPending => status == 'pending';
  bool get isUnknown => status == 'unknown';

  factory TrackDetectionResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    return TrackDetectionResponse(
      status: payload['status'] as String,
      trackId: payload['trackId'] as String?,
      layoutId: payload['layoutId'] as String?,
      trackName: payload['trackName'] as String?,
      layoutName: payload['layoutName'] as String?,
      confidence: (payload['confidence'] as num?)?.toDouble() ?? 0,
      reasons: (payload['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
      nextAction: payload['nextAction'] as String?,
      capabilities: parseTrackCapabilities(
        payload['capabilities'] ?? payload['trackCapabilities'],
      ),
    );
  }
}

class CreateSessionRequest {
  final String source;
  final String game;
  final String platform;
  final String driverAlias;
  final String? trackId;
  final int startedUnixMs;

  const CreateSessionRequest({
    required this.source,
    required this.game,
    required this.platform,
    required this.driverAlias,
    this.trackId,
    required this.startedUnixMs,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'source': source,
      'game': game,
      'platform': platform,
      'driverAlias': driverAlias,
      'startedUnixMs': startedUnixMs,
    };
    if (trackId != null && trackId!.isNotEmpty) {
      json['trackId'] = trackId;
    }
    return json;
  }
}

class CreateSessionResponse {
  final String sessionId;

  const CreateSessionResponse({required this.sessionId});

  factory CreateSessionResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    final session = payload['session'] as Map<String, dynamic>;
    return CreateSessionResponse(sessionId: session['id'] as String);
  }
}

class FinishSessionRequest {
  final int endedUnixMs;

  const FinishSessionRequest({required this.endedUnixMs});

  Map<String, dynamic> toJson() => {'endedUnixMs': endedUnixMs};
}

class FinishSessionResponse {
  final String status;

  const FinishSessionResponse({required this.status});

  factory FinishSessionResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    return FinishSessionResponse(status: payload['status'] as String);
  }
}

class RaceEngineerAdviceRequest {
  final int? sinceUnixMs;
  final int? maxEvents;

  const RaceEngineerAdviceRequest({this.sinceUnixMs, this.maxEvents});

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (sinceUnixMs != null) json['sinceUnixMs'] = sinceUnixMs;
    if (maxEvents != null) json['maxEvents'] = maxEvents;
    return json;
  }
}

class RaceEngineerAdviceWindow {
  final int? sinceUnixMs;
  final int? untilUnixMs;
  final int? maxEvents;
  final int? derivedSignalCount;

  const RaceEngineerAdviceWindow({
    this.sinceUnixMs,
    this.untilUnixMs,
    this.maxEvents,
    this.derivedSignalCount,
  });

  factory RaceEngineerAdviceWindow.fromJson(Map<String, dynamic> json) {
    return RaceEngineerAdviceWindow(
      sinceUnixMs: (json['sinceUnixMs'] as num?)?.toInt(),
      untilUnixMs: (json['untilUnixMs'] as num?)?.toInt(),
      maxEvents: (json['maxEvents'] as num?)?.toInt(),
      derivedSignalCount: (json['derivedSignalCount'] as num?)?.toInt(),
    );
  }
}

class RaceEngineerSignal {
  final String type;
  final String? severity;
  final String? label;
  final String? message;
  final String? status;
  final String? title;
  final String? summary;
  final double? confidence;
  final int? timestampUnixMs;

  const RaceEngineerSignal({
    required this.type,
    this.severity,
    this.label,
    this.message,
    this.status,
    this.title,
    this.summary,
    this.confidence,
    this.timestampUnixMs,
  });

  String get displayLabel => label ?? title ?? _humanizeSignalType(type);

  String? get displayMessage {
    final text = message ?? summary;
    if (text == null || text.trim().isEmpty) return null;
    return text;
  }

  String? get displaySeverity {
    final value = severity ?? status;
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  factory RaceEngineerSignal.fromJson(Map<String, dynamic> json) {
    return RaceEngineerSignal(
      type: (json['type'] as String?) ?? (json['signalType'] as String?) ?? 'unknown',
      severity: json['severity'] as String?,
      label: (json['label'] as String?) ?? (json['name'] as String?),
      message:
          (json['message'] as String?) ??
          (json['description'] as String?) ??
          (json['detail'] as String?) ??
          (json['details'] as String?) ??
          (json['text'] as String?),
      status: json['status'] as String?,
      title: json['title'] as String?,
      summary: json['summary'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      timestampUnixMs:
          (json['timestampUnixMs'] as num?)?.toInt() ??
          (json['generatedAtUnixMs'] as num?)?.toInt(),
    );
  }
}

class RaceEngineerProviderInfo {
  final String? provider;
  final String? model;
  final String? status;
  final String? finishReason;
  final String? providerName;
  final int? retryAfterSeconds;

  const RaceEngineerProviderInfo({
    this.provider,
    this.model,
    this.status,
    this.finishReason,
    this.providerName,
    this.retryAfterSeconds,
  });

  factory RaceEngineerProviderInfo.fromJson(Map<String, dynamic> json) {
    return RaceEngineerProviderInfo(
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      status: json['status'] as String?,
      finishReason: json['finishReason'] as String?,
      providerName: json['providerName'] as String?,
      retryAfterSeconds: (json['retryAfterSeconds'] as num?)?.toInt(),
    );
  }
}

class RaceEngineerAdviceResponse {
  final String sessionId;
  final String status;
  final String? message;
  final String? advice;
  final List<String> referencedEvents;
  final List<RaceEngineerSignal> signals;
  final RaceEngineerAdviceWindow? window;
  final int? generatedAtUnixMs;
  final RaceEngineerProviderInfo? providerInfo;

  const RaceEngineerAdviceResponse({
    required this.sessionId,
    required this.status,
    this.message,
    this.advice,
    this.referencedEvents = const [],
    this.signals = const [],
    this.window,
    this.generatedAtUnixMs,
    this.providerInfo,
  });

  bool get hasAdvice =>
      (message != null && message!.trim().isNotEmpty) ||
      (advice != null && advice!.trim().isNotEmpty);
  bool get hasNoEvents => status == 'no_events';
  bool get hasSignals => signals.isNotEmpty;
  bool get isRateLimited =>
      status == 'rate_limited' ||
      providerInfo?.finishReason == 'rate_limited' ||
      providerInfo?.status == 'rate_limited';

  factory RaceEngineerAdviceResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    return RaceEngineerAdviceResponse(
      sessionId: payload['sessionId'] as String,
      status: payload['status'] as String,
      message: payload['message'] as String?,
      advice: payload['advice'] as String?,
      referencedEvents:
          (payload['referencedEvents'] as List<dynamic>?)?.cast<String>() ??
          (payload['referencedEventIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
      signals: (payload['signals'] as List<dynamic>?)
          ?.whereType<Map<String, dynamic>>()
          .map(RaceEngineerSignal.fromJson)
          .toList(growable: false) ??
          const [],
      window: payload['window'] != null
          ? RaceEngineerAdviceWindow.fromJson(
              payload['window'] as Map<String, dynamic>,
            )
          : null,
      generatedAtUnixMs:
          (payload['generatedAtUnixMs'] as num?)?.toInt() ??
          _parseGeneratedAtMs(payload['generatedAt'] as String?),
      providerInfo: payload['providerInfo'] != null
          ? RaceEngineerProviderInfo.fromJson(
              payload['providerInfo'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

int? _parseGeneratedAtMs(String? generatedAt) {
  if (generatedAt == null) return null;
  return DateTime.tryParse(generatedAt)?.millisecondsSinceEpoch;
}

String _humanizeSignalType(String type) {
  final words = type.replaceAll('_', ' ').trim();
  if (words.isEmpty) return 'Signal';
  return words
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

class EngineerEvent {
  final String eventId;
  final String sessionId;
  final String version;
  final String type;
  final String severity;
  final double confidence;
  final int timestampUnixMs;
  final int lapNumber;
  final Map<String, dynamic>? corner;
  final String source;

  const EngineerEvent({
    required this.eventId,
    required this.sessionId,
    required this.version,
    required this.type,
    required this.severity,
    required this.confidence,
    required this.timestampUnixMs,
    required this.lapNumber,
    this.corner,
    required this.source,
  });

  factory EngineerEvent.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    final sourceObj = payload['source'] as Map<String, dynamic>;
    return EngineerEvent(
      eventId: payload['eventId'] as String,
      sessionId: payload['sessionId'] as String,
      version: payload['version'] as String,
      type: payload['type'] as String,
      severity: payload['severity'] as String,
      confidence: (payload['confidence'] as num).toDouble(),
      timestampUnixMs: (payload['timestampUnixMs'] as num).toInt(),
      lapNumber: (payload['lapNumber'] as num).toInt(),
      corner: payload['corner'] as Map<String, dynamic>?,
      source: '${sourceObj['kind']}:${sourceObj['ruleId']}',
    );
  }

  static List<EngineerEvent> listFromResponseJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    final events =
        (payload['events'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
        [];
    return events.map(EngineerEvent.fromJson).toList();
  }
}
