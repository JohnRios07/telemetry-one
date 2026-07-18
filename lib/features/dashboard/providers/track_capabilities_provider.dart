import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/track_capabilities_dto.dart';
import '../../../core/backend/v2_bridge_providers.dart';
import 'manual_track_selection_provider.dart';

final effectiveTrackCapabilitiesProvider = Provider<TrackCapabilitiesDto?>((
  ref,
) {
  final manualState = ref.watch(manualTrackSelectionProvider);
  final appliedCapabilities = manualState.appliedCapabilities;
  if (appliedCapabilities != null) {
    return appliedCapabilities;
  }

  final detection = ref.watch(backendTrackDetectionProvider);
  return detection.maybeWhen(
    data: (response) => response?.capabilities,
    orElse: () => null,
  );
});
