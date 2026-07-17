import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backend_client.dart';
import 'backend_config.dart';
import 'backend_data_bridge.dart';
import 'backend_sync_provider.dart';
import 'telemetry_frame_dto.dart';
import '../../features/dashboard/providers/manual_track_selection_provider.dart';

/// Provider for the backend data bridge.
final backendDataBridgeProvider = Provider<BackendDataBridge>((ref) {
  final config = ref.watch(backendConfigProvider);
  final client = ref.watch(backendClientProvider);
  return BackendDataBridge(client: client, config: config);
});

/// Feature flag: whether V2 backend-sourced data is enabled.
final backendV2EnabledProvider = Provider<bool>((ref) {
  return ref.watch(backendConfigProvider).useV2Data;
});

/// Track detection sourced from backend V2.
///
/// Returns null when:
/// - V2 feature flag is disabled (default)
/// - Backend is unreachable or returns an error
/// - Track detection is still pending on the backend
///
/// When null, V1 local session data remains the source of truth.
final backendTrackDetectionProvider =
    FutureProvider.autoDispose<TrackDetectionResponse?>((ref) async {
  final bridge = ref.watch(backendDataBridgeProvider);
  if (!bridge.isV2Enabled) return null;

  final syncState = ref.watch(backendSyncProvider);
  return bridge.getTrackDetection(syncState.sessionId);
});

/// Effective backend session ID for live dashboard features.
final backendEffectiveSessionIdProvider = Provider<String>((ref) {
  return ref.watch(backendSyncProvider.select((state) => state.effectiveSessionId));
});

/// Whether manual track/layout selection can write to a backend-owned session.
final manualTrackSelectionAvailabilityProvider = Provider<bool>((ref) {
  final syncState = ref.watch(backendSyncProvider);
  return ref.watch(backendV2EnabledProvider) && syncState.backendSessionId != null;
});

/// Session-bound manual track/layout controller for the live dashboard.
final liveManualTrackSelectionProvider = manualTrackSelectionProvider;

/// Engineer events sourced from backend V2 for a given session.
///
/// Returns null when:
/// - V2 feature flag is disabled (default)
/// - Backend is unreachable or returns an error
/// - 501 not_implemented (create-session not yet persistent)
///
/// Returns an empty list when the session exists but has no events.
final backendEventsProvider = FutureProvider.autoDispose
    .family<List<EngineerEvent>?, String>((ref, sessionId) async {
  final bridge = ref.watch(backendDataBridgeProvider);
  if (!bridge.isV2Enabled) return null;

  return bridge.getEvents(sessionId);
});
