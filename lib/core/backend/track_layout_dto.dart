import 'dart:convert';

import 'track_capabilities_dto.dart';

Map<String, dynamic> _responsePayload(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is Map<String, dynamic>) {
    final nestedSession = data['session'];
    if (nestedSession is Map<String, dynamic>) {
      return nestedSession;
    }

    return data;
  }

  final session = json['session'];
  if (session is Map<String, dynamic>) {
    return session;
  }

  return json;
}

Map<String, dynamic> _catalogPayload(Map<String, dynamic> json) {
  final payload = _responsePayload(json);
  final catalog = payload['catalog'];
  if (catalog is Map<String, dynamic>) {
    return catalog;
  }
  return payload;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw TrackLayoutContractException('Missing required field: $key');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return null;
}

class TrackLayoutContractException extends FormatException {
  TrackLayoutContractException(super.message);
}

class TrackCatalogLayout {
  final String layoutId;
  final String? layoutName;

  const TrackCatalogLayout({required this.layoutId, this.layoutName});

  String get displayName => layoutName?.trim().isNotEmpty == true
      ? layoutName!.trim()
      : layoutId;

  factory TrackCatalogLayout.fromJson(Map<String, dynamic> json) {
    return TrackCatalogLayout(
      layoutId: _requiredString(json, 'layoutId'),
      layoutName: _optionalString(json, 'layoutName'),
    );
  }
}

class TrackCatalogTrack {
  final String trackId;
  final String? trackName;
  final List<TrackCatalogLayout> layouts;

  const TrackCatalogTrack({
    required this.trackId,
    this.trackName,
    required this.layouts,
  });

  String get displayName => trackName?.trim().isNotEmpty == true
      ? trackName!.trim()
      : trackId;

  TrackCatalogLayout? layoutFor(String? layoutId) {
    if (layoutId == null) return null;
    for (final layout in layouts) {
      if (layout.layoutId == layoutId) return layout;
    }
    return null;
  }

  factory TrackCatalogTrack.fromJson(Map<String, dynamic> json) {
    final rawLayouts = json['layouts'] ?? json['trackLayouts'];
    if (rawLayouts is! List) {
      throw TrackLayoutContractException(
        'Missing layouts for track ${json['trackId'] ?? 'unknown'}',
      );
    }

    return TrackCatalogTrack(
      trackId: _requiredString(json, 'trackId'),
      trackName: _optionalString(json, 'trackName'),
      layouts: rawLayouts
          .map((entry) {
            if (entry is! Map<String, dynamic>) {
              throw TrackLayoutContractException(
                'Invalid layout entry for track ${json['trackId']}',
              );
            }
            return TrackCatalogLayout.fromJson(entry);
          })
          .toList(growable: false),
    );
  }
}

class TrackLayoutsCatalogResponse {
  final List<TrackCatalogTrack> tracks;

  const TrackLayoutsCatalogResponse({required this.tracks});

  TrackCatalogTrack? trackFor(String? trackId) {
    if (trackId == null) return null;
    for (final track in tracks) {
      if (track.trackId == trackId) return track;
    }
    return null;
  }

  factory TrackLayoutsCatalogResponse.fromJson(Map<String, dynamic> json) {
    final payload = _catalogPayload(json);
    final rawTracks = payload['tracks'];
    if (rawTracks is! List) {
      throw TrackLayoutContractException('Missing tracks catalog payload');
    }

    return TrackLayoutsCatalogResponse(
      tracks: rawTracks
          .map((entry) {
            if (entry is! Map<String, dynamic>) {
              throw TrackLayoutContractException('Invalid track entry');
            }
            return TrackCatalogTrack.fromJson(entry);
          })
          .toList(growable: false),
    );
  }
}

class UpdateSessionTrackLayoutRequest {
  final String trackId;
  final String layoutId;

  const UpdateSessionTrackLayoutRequest({
    required this.trackId,
    required this.layoutId,
  });

  Map<String, dynamic> toJson() => {'trackId': trackId, 'layoutId': layoutId};
}

class UpdateSessionTrackLayoutResponse {
  final String sessionId;
  final String trackId;
  final String layoutId;
  final String? detectedTrackId;
  final String? detectedLayoutId;
  final TrackCapabilitiesDto? capabilities;

  const UpdateSessionTrackLayoutResponse({
    required this.sessionId,
    required this.trackId,
    required this.layoutId,
    this.detectedTrackId,
    this.detectedLayoutId,
    this.capabilities,
  });

  factory UpdateSessionTrackLayoutResponse.fromJson(Map<String, dynamic> json) {
    final payload = _responsePayload(json);
    return UpdateSessionTrackLayoutResponse(
      sessionId: _requiredString(payload, 'sessionId'),
      trackId: _requiredString(payload, 'trackId'),
      layoutId: _requiredString(payload, 'layoutId'),
      detectedTrackId: _optionalString(payload, 'detectedTrackId'),
      detectedLayoutId: _optionalString(payload, 'detectedLayoutId'),
      capabilities: parseTrackCapabilities(
        payload['trackCapabilities'] ?? payload['capabilities'],
      ),
    );
  }
}

String trackLayoutsCatalogToJsonString(TrackLayoutsCatalogResponse response) {
  return jsonEncode({
    'tracks': response.tracks
        .map(
          (track) => {
            'trackId': track.trackId,
            if (track.trackName != null) 'trackName': track.trackName,
            'layouts': track.layouts
                .map(
                  (layout) => {
                    'layoutId': layout.layoutId,
                    if (layout.layoutName != null) 'layoutName': layout.layoutName,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false),
  });
}
