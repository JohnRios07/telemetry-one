import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'telemetry_frame_dto.dart';
import 'v2_bridge_providers.dart';

/// V2 backend augmentation available for optional consumption alongside
/// V1 local Engineer/Coach data under the [useV2Data] feature flag.
///
/// Never replaces V1 — always layers on top.
class EngineerV2Augmentation {
  final bool v2Enabled;

  /// Track detection for the backend sync sessionId, or null when V2 is
  /// disabled, backend is unreachable, or track is still pending.
  final TrackDetectionResponse? trackDetection;

  /// Human-readable status for debugging and UI fallback.
  final String status;

  const EngineerV2Augmentation({
    required this.v2Enabled,
    this.trackDetection,
    required this.status,
  });

  bool get hasBackendData => trackDetection != null;
}

/// Provider that composes V2 bridge data for optional V1 Engineer augmentation.
///
/// **Does NOT modify V1 providers** — V1 local data (session, summary,
/// comparison, recommendations, coach report) remains the exclusive source
/// of truth. This provider merely reports whether V2 augmentation is
/// available for the backend sync session.
///
/// Returns a non-null [EngineerV2Augmentation] that always has a valid
/// [status]:
/// - `v2_disabled` — feature flag is off, all fields null.
/// - `no_data` — V2 enabled but no data available yet (pending, error, 501).
/// - `track_detected` — V2 enabled and track detection returned data.
final engineerV2AugmentationProvider =
    FutureProvider.autoDispose<EngineerV2Augmentation>((ref) async {
  final v2Enabled = ref.watch(backendV2EnabledProvider);

  if (!v2Enabled) {
    return const EngineerV2Augmentation(
      v2Enabled: false,
      status: 'v2_disabled',
    );
  }

  final track = await ref.watch(backendTrackDetectionProvider.future);

  if (track != null) {
    return EngineerV2Augmentation(
      v2Enabled: true,
      trackDetection: track,
      status: 'track_detected',
    );
  }

  return const EngineerV2Augmentation(
    v2Enabled: true,
    status: 'no_data',
  );
});
