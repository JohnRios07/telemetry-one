enum TrackCapabilityState { available, partial, unavailable }

TrackCapabilityState? _trackCapabilityStateFromValue(Object? value) {
  final normalized = switch (value) {
    String text => text.trim().toLowerCase(),
    _ => '',
  };

  return switch (normalized) {
    'available' => TrackCapabilityState.available,
    'partial' => TrackCapabilityState.partial,
    'unavailable' => TrackCapabilityState.unavailable,
    _ => null,
  };
}

String? _normalizeReason(Object? value) {
  if (value is! String) return null;
  final reason = value.trim();
  return reason.isEmpty ? null : reason;
}

class TrackCapabilitiesDto {
  final TrackCapabilityState state;
  final String? reason;

  const TrackCapabilitiesDto({required this.state, this.reason});

  bool get hasReason => reason?.trim().isNotEmpty == true;

  String get stateLabel => switch (state) {
    TrackCapabilityState.available => 'Available',
    TrackCapabilityState.partial => 'Partial',
    TrackCapabilityState.unavailable => 'Unavailable',
  };

  factory TrackCapabilitiesDto.fromJson(Map<String, dynamic> json) {
    final state = _trackCapabilityStateFromValue(
      json['state'] ?? json['status'] ?? json['value'],
    );
    if (state == null) {
      throw FormatException('Missing capability state');
    }

    return TrackCapabilitiesDto(
      state: state,
      reason: _normalizeReason(json['reason'] ?? json['message'] ?? json['details']),
    );
  }
}

TrackCapabilitiesDto? parseTrackCapabilities(Object? payload) {
  if (payload == null) return null;
  if (payload is TrackCapabilitiesDto) return payload;

  if (payload is String) {
    final state = _trackCapabilityStateFromValue(payload);
    if (state == null) return null;
    return TrackCapabilitiesDto(state: state);
  }

  if (payload is Map<String, dynamic>) {
    try {
      return TrackCapabilitiesDto.fromJson(payload);
    } on FormatException {
      return null;
    }
  }

  return null;
}
