import 'dart:convert';

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

  const FrameBatchRequest({
    required this.sessionId,
    required this.frames,
  });

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'frames': frames.map((f) => f.toJson()).toList(),
  };
}

class RejectionReasonCount {
  final String code;
  final int count;

  const RejectionReasonCount({
    required this.code,
    required this.count,
  });

  factory RejectionReasonCount.fromJson(Map<String, dynamic> json) {
    return RejectionReasonCount(
      code: json['code'] as String,
      count: (json['count'] as num).toInt(),
    );
  }
}

class RejectionSummary {
  final List<RejectionReasonCount> reasons;

  String? get topReasonCode =>
      reasons.isNotEmpty ? reasons.first.code : null;

  const RejectionSummary({required this.reasons});

  factory RejectionSummary.fromJson(Map<String, dynamic> json) {
    final reasonsList = (json['reasons'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>() ??
        [];
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
    return IngestResponse(
      sessionId: json['sessionId'] as String,
      receivedFrames: (json['receivedFrames'] as num).toInt(),
      acceptedFrames: (json['acceptedFrames'] as num).toInt(),
      rejectedFrames: (json['rejectedFrames'] as num).toInt(),
      acceptedFromUnixMs: (json['acceptedFromUnixMs'] as num).toInt(),
      acceptedToUnixMs: (json['acceptedToUnixMs'] as num).toInt(),
      status: json['status'] as String,
      rejectionSummary: json['rejectionSummary'] != null
          ? RejectionSummary.fromJson(
              json['rejectionSummary'] as Map<String, dynamic>)
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
      return rejectionCode == 'batch_too_large' || rejectionCode == 'frames_empty';
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

  const BackendError({
    required this.code,
    required this.message,
    this.details,
  });

  bool get isBadRequest => code == 'bad_request';
  bool get isNotImplemented => code == 'not_implemented';
  bool get isInternalError => code == 'internal_error';
  bool get isSessionNotFound => code == 'session_not_found';
  bool get isSessionFinished => code == 'session_finished';
  bool get isRetryable =>
    code == 'internal_error' ||
    code == 'service_unavailable';

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

  const TrackDetectionResponse({
    required this.status,
    this.trackId,
    this.layoutId,
    this.trackName,
    this.layoutName,
    this.confidence = 0,
    this.reasons = const [],
    this.nextAction,
  });

  bool get isDetected => status == 'detected';
  bool get isPending => status == 'pending';
  bool get isUnknown => status == 'unknown';

  factory TrackDetectionResponse.fromJson(Map<String, dynamic> json) {
    return TrackDetectionResponse(
      status: json['status'] as String,
      trackId: json['trackId'] as String?,
      layoutId: json['layoutId'] as String?,
      trackName: json['trackName'] as String?,
      layoutName: json['layoutName'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      reasons: (json['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
      nextAction: json['nextAction'] as String?,
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
    final session = json['session'] as Map<String, dynamic>;
    return CreateSessionResponse(
      sessionId: session['id'] as String,
    );
  }
}

class FinishSessionRequest {
  final int endedUnixMs;

  const FinishSessionRequest({required this.endedUnixMs});

  Map<String, dynamic> toJson() => {
    'endedUnixMs': endedUnixMs,
  };
}

class FinishSessionResponse {
  final String status;

  const FinishSessionResponse({required this.status});

  factory FinishSessionResponse.fromJson(Map<String, dynamic> json) {
    return FinishSessionResponse(
      status: json['status'] as String,
    );
  }
}

class RaceEngineerAdviceRequest {
  final int? sinceUnixMs;
  final int? maxEvents;

  const RaceEngineerAdviceRequest({
    this.sinceUnixMs,
    this.maxEvents,
  });

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

  const RaceEngineerAdviceWindow({
    this.sinceUnixMs,
    this.untilUnixMs,
    this.maxEvents,
  });

  factory RaceEngineerAdviceWindow.fromJson(Map<String, dynamic> json) {
    return RaceEngineerAdviceWindow(
      sinceUnixMs: (json['sinceUnixMs'] as num?)?.toInt(),
      untilUnixMs: (json['untilUnixMs'] as num?)?.toInt(),
      maxEvents: (json['maxEvents'] as num?)?.toInt(),
    );
  }
}

class RaceEngineerProviderInfo {
  final String? provider;
  final String? model;
  final String? status;

  const RaceEngineerProviderInfo({
    this.provider,
    this.model,
    this.status,
  });

  factory RaceEngineerProviderInfo.fromJson(Map<String, dynamic> json) {
    return RaceEngineerProviderInfo(
      provider: json['provider'] as String?,
      model: json['model'] as String?,
      status: json['status'] as String?,
    );
  }
}

class RaceEngineerAdviceResponse {
  final String sessionId;
  final String status;
  final String? message;
  final String? advice;
  final List<String> referencedEvents;
  final RaceEngineerAdviceWindow? window;
  final int? generatedAtUnixMs;
  final RaceEngineerProviderInfo? providerInfo;

  const RaceEngineerAdviceResponse({
    required this.sessionId,
    required this.status,
    this.message,
    this.advice,
    this.referencedEvents = const [],
    this.window,
    this.generatedAtUnixMs,
    this.providerInfo,
  });

  bool get hasAdvice =>
      (message != null && message!.trim().isNotEmpty) ||
      (advice != null && advice!.trim().isNotEmpty);
  bool get hasNoEvents => status == 'no_events';

  factory RaceEngineerAdviceResponse.fromJson(Map<String, dynamic> json) {
    return RaceEngineerAdviceResponse(
      sessionId: json['sessionId'] as String,
      status: json['status'] as String,
      message: json['message'] as String?,
      advice: json['advice'] as String?,
      referencedEvents:
          (json['referencedEvents'] as List<dynamic>?)?.cast<String>() ??
              (json['referencedEventIds'] as List<dynamic>?)?.cast<String>() ??
              const [],
      window: json['window'] != null
          ? RaceEngineerAdviceWindow.fromJson(
              json['window'] as Map<String, dynamic>)
          : null,
      generatedAtUnixMs: (json['generatedAtUnixMs'] as num?)?.toInt() ??
          _parseGeneratedAtMs(json['generatedAt'] as String?),
      providerInfo: json['providerInfo'] != null
          ? RaceEngineerProviderInfo.fromJson(
              json['providerInfo'] as Map<String, dynamic>)
          : null,
    );
  }
}

int? _parseGeneratedAtMs(String? generatedAt) {
  if (generatedAt == null) return null;
  return DateTime.tryParse(generatedAt)?.millisecondsSinceEpoch;
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
    final sourceObj = json['source'] as Map<String, dynamic>;
    return EngineerEvent(
      eventId: json['eventId'] as String,
      sessionId: json['sessionId'] as String,
      version: json['version'] as String,
      type: json['type'] as String,
      severity: json['severity'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      timestampUnixMs: (json['timestampUnixMs'] as num).toInt(),
      lapNumber: (json['lapNumber'] as num).toInt(),
      corner: json['corner'] as Map<String, dynamic>?,
      source: '${sourceObj['kind']}:${sourceObj['ruleId']}',
    );
  }
}
