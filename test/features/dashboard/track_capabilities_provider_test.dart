import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/telemetry_frame_dto.dart';
import 'package:telemetry_one/core/backend/track_capabilities_dto.dart';
import 'package:telemetry_one/core/backend/track_layout_dto.dart';
import 'package:telemetry_one/core/backend/v2_bridge_providers.dart';
import 'package:telemetry_one/features/dashboard/providers/manual_track_selection_provider.dart';
import 'package:telemetry_one/features/dashboard/providers/track_capabilities_provider.dart';

class _FakeTrackCapabilitiesClient extends BackendClient {
  _FakeTrackCapabilitiesClient()
      : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  UpdateSessionTrackLayoutResponse? updateResponse;

  @override
  Future<TrackLayoutsCatalogResponse> getTrackLayouts() async {
    return const TrackLayoutsCatalogResponse(
      tracks: [
        TrackCatalogTrack(
          trackId: 'gt7_watkins_glen_international',
          trackName: 'Watkins Glen International',
          layouts: [TrackCatalogLayout(layoutId: 'full_course')],
        ),
      ],
    );
  }

  @override
  Future<UpdateSessionTrackLayoutResponse> updateSessionTrackLayout(
    String sessionId,
    String trackId,
    String layoutId,
  ) async {
    return updateResponse ??
        UpdateSessionTrackLayoutResponse(
          sessionId: sessionId,
          trackId: trackId,
          layoutId: layoutId,
          capabilities: const TrackCapabilitiesDto(
            state: TrackCapabilityState.available,
          ),
        );
  }
}

class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state)
      : super(config: const BackendConfig()) {
    this.state = state;
  }

  @override
  void dispose() {}
}

ProviderContainer _container({
  required TrackDetectionResponse? detection,
  required BackendSyncState syncState,
  required _FakeTrackCapabilitiesClient client,
}) {
  return ProviderContainer(
    overrides: [
      backendClientProvider.overrideWithValue(client),
      backendSyncProvider.overrideWith((ref) => _MockSyncNotifier(syncState)),
      backendTrackDetectionProvider.overrideWith(
        (ref) async => detection,
      ),
    ],
  );
}

void main() {
  test('falls back to detection capabilities when no manual override exists',
      () async {
    final container = _container(
      detection: const TrackDetectionResponse(
        status: 'detected',
        capabilities: TrackCapabilitiesDto(
          state: TrackCapabilityState.partial,
          reason: 'Detection is still coarse.',
        ),
      ),
      syncState: const BackendSyncState(
        sessionId: 'local_123',
        backendSessionId: 'session_abc123',
        alignmentStatus: SessionAlignmentStatus.created,
      ),
      client: _FakeTrackCapabilitiesClient(),
    );
    addTearDown(container.dispose);

    await container.read(backendTrackDetectionProvider.future);

    final value = container.read(effectiveTrackCapabilitiesProvider);

    expect(value?.state, TrackCapabilityState.partial);
    expect(value?.reason, 'Detection is still coarse.');
  });

  test('manual applied capabilities override detection capabilities', () async {
    final manualState = ManualTrackSelectionState(
      sessionId: 'session_abc123',
      backendSessionId: 'session_abc123',
      appliedCapabilities: const TrackCapabilitiesDto(
        state: TrackCapabilityState.available,
        reason: 'Manual selection resolved the layout.',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        backendTrackDetectionProvider.overrideWith(
          (ref) async => const TrackDetectionResponse(
            status: 'detected',
            capabilities: TrackCapabilitiesDto(
              state: TrackCapabilityState.unavailable,
              reason: 'Detection stale.',
            ),
          ),
        ),
        manualTrackSelectionProvider.overrideWith(
          (ref) => _ManualStateNotifier(manualState),
        ),
      ],
    );
    addTearDown(container.dispose);

    final value = container.read(effectiveTrackCapabilitiesProvider);

    expect(value?.state, TrackCapabilityState.available);
    expect(value?.reason, 'Manual selection resolved the layout.');
  });

  test('submitSelection refreshes effective capabilities from manual response',
      () async {
    final client = _FakeTrackCapabilitiesClient();
    final container = _container(
      detection: const TrackDetectionResponse(
        status: 'detected',
        capabilities: TrackCapabilitiesDto(
          state: TrackCapabilityState.partial,
          reason: 'Detection fallback.',
        ),
      ),
      syncState: const BackendSyncState(
        sessionId: 'local_123',
        backendSessionId: 'session_abc123',
        alignmentStatus: SessionAlignmentStatus.created,
      ),
      client: client,
    );
    addTearDown(container.dispose);

    await container.read(backendTrackDetectionProvider.future);

    final notifier = container.read(manualTrackSelectionProvider.notifier);
    await notifier.loadCatalog();
    notifier
      ..selectTrack('gt7_watkins_glen_international')
      ..selectLayout('full_course');

    expect(
      container.read(effectiveTrackCapabilitiesProvider)?.state,
      TrackCapabilityState.partial,
    );

    final submitted = await notifier.submitSelection();
    expect(submitted, isTrue);

    final value = container.read(effectiveTrackCapabilitiesProvider);
    expect(value?.state, TrackCapabilityState.available);
    expect(value?.reason, isNull);
  });
}

class _ManualStateNotifier extends ManualTrackSelectionNotifier {
  _ManualStateNotifier(ManualTrackSelectionState state)
      : super(
          client: _FakeTrackCapabilitiesClient(),
          sessionId: state.sessionId,
          backendSessionId: state.backendSessionId,
        ) {
    this.state = state;
  }

  @override
  void dispose() {}
}
