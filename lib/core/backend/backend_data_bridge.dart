import 'package:flutter/foundation.dart';
import 'backend_client.dart';
import 'backend_config.dart';
import 'telemetry_frame_dto.dart';

/// Read-only bridge that sources V2 backend data where available.
///
/// Respects the [BackendConfig.useV2Data] feature flag:
/// - flag == false → returns null immediately (no network calls)
/// - flag == true  → calls implemented backend endpoints and returns data,
///                    or null on any error (network, 501, server error)
///
/// Graceful degradation: null results let V1 local providers remain the
/// source of truth without breaking UI or recording.
class BackendDataBridge {
  final BackendClient _client;
  final BackendConfig _config;

  BackendDataBridge({
    BackendClient? client,
    BackendConfig? config,
  })  : _client = client ?? BackendClient(),
        _config = config ?? const BackendConfig();

  bool get isV2Enabled => _config.useV2Data;

  Future<TrackDetectionResponse?> getTrackDetection(String sessionId) async {
    if (!_config.useV2Data) return null;

    try {
      return await _client.getTrackDetection(sessionId);
    } on BackendRequestException catch (e) {
      debugPrint('[BackendDataBridge] getTrackDetection error: '
          '${e.error.code} — ${e.error.message}');
      if (e.error.isNotImplemented) return null;
      return null;
    } catch (_) {
      debugPrint('[BackendDataBridge] getTrackDetection unexpected error');
      return null;
    }
  }

  Future<List<EngineerEvent>?> getEvents(
    String sessionId, {
    int? lapNumber,
    String? cornerId,
    String? type,
  }) async {
    if (!_config.useV2Data) return null;

    try {
      return await _client.getEvents(
        sessionId,
        lapNumber: lapNumber,
        cornerId: cornerId,
        type: type,
      );
    } on BackendRequestException catch (e) {
      debugPrint('[BackendDataBridge] getEvents error: '
          '${e.error.code} — ${e.error.message}');
      if (e.error.isNotImplemented) return null;
      return null;
    } catch (_) {
      debugPrint('[BackendDataBridge] getEvents unexpected error');
      return null;
    }
  }
}
