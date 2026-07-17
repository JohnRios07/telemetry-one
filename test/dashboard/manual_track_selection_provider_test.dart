import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemetry_one/core/backend/backend_client.dart';
import 'package:telemetry_one/core/backend/backend_config.dart';
import 'package:telemetry_one/core/backend/backend_sync_provider.dart';
import 'package:telemetry_one/core/backend/track_layout_dto.dart';
import 'package:telemetry_one/features/dashboard/providers/manual_track_selection_provider.dart';

class _FakeManualTrackClient extends BackendClient {
  int catalogCalls = 0;
  int updateCalls = 0;
  String? lastSessionId;
  String? lastTrackId;
  String? lastLayoutId;
  TrackLayoutsCatalogResponse? catalogResponse;
  UpdateSessionTrackLayoutResponse? updateResponse;
  BackendRequestException? catalogException;
  BackendRequestException? updateException;

  _FakeManualTrackClient()
    : super(config: const BackendConfig(baseUrl: 'http://example.test'));

  @override
  Future<TrackLayoutsCatalogResponse> getTrackLayouts() async {
    catalogCalls++;
    final exception = catalogException;
    if (exception != null) throw exception;
    return catalogResponse ??
        const TrackLayoutsCatalogResponse(
          tracks: [
            TrackCatalogTrack(
              trackId: 'gt7_watkins_glen_international',
              trackName: 'Watkins Glen International',
              layouts: [
                TrackCatalogLayout(layoutId: 'full_course', layoutName: 'Full Course'),
                TrackCatalogLayout(layoutId: 'boot', layoutName: 'Boot'),
              ],
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
    updateCalls++;
    lastSessionId = sessionId;
    lastTrackId = trackId;
    lastLayoutId = layoutId;
    final exception = updateException;
    if (exception != null) throw exception;
    return updateResponse ??
        UpdateSessionTrackLayoutResponse(
          sessionId: sessionId,
          trackId: trackId,
          layoutId: layoutId,
          detectedTrackId: 'detected_track_id'
              ,
          detectedLayoutId: 'detected_layout_id',
        );
  }
}

class _MockSyncNotifier extends BackendSyncNotifier {
  _MockSyncNotifier(BackendSyncState state)
    : super(config: const BackendConfig()) {
    this.state = state;
  }

  void update(BackendSyncState state) {
    this.state = state;
  }

  @override
  void dispose() {}
}

ProviderContainer _container({
  required BackendSyncState syncState,
  required _FakeManualTrackClient client,
}) {
  return ProviderContainer(
    overrides: [
      backendClientProvider.overrideWithValue(client),
      backendSyncProvider.overrideWith((ref) => _MockSyncNotifier(syncState)),
    ],
  );
}

void main() {
  test('local-only session blocks loading and writes', () async {
    final client = _FakeManualTrackClient();
    final container = _container(
      syncState: const BackendSyncState(sessionId: 'local_123'),
      client: client,
    );
    addTearDown(container.dispose);

    final notifier = container.read(manualTrackSelectionProvider.notifier);
    expect(container.read(manualTrackSelectionProvider).canWrite, isFalse);

    await notifier.loadCatalog();

    final state = container.read(manualTrackSelectionProvider);
    expect(state.catalogErrorMessage, 'Awaiting aligned backend session.');
    expect(state.phase, ManualTrackSelectionPhase.failed);
    expect(client.catalogCalls, 0);

    final submitted = await notifier.submitSelection();
    expect(submitted, isFalse);
    expect(container.read(manualTrackSelectionProvider).actionErrorMessage,
        'Awaiting aligned backend session.');
  });

  test('loads catalog, submits valid pair, and uses backend session id',
      () async {
    final client = _FakeManualTrackClient();
    final container = _container(
      syncState: const BackendSyncState(
        sessionId: 'local_123',
        backendSessionId: 'session_abc123',
        alignmentStatus: SessionAlignmentStatus.created,
      ),
      client: client,
    );
    addTearDown(container.dispose);

    final notifier = container.read(manualTrackSelectionProvider.notifier);
    await notifier.loadCatalog();
    notifier
      ..selectTrack('gt7_watkins_glen_international')
      ..selectLayout('full_course');

    final submitted = await notifier.submitSelection();
    final state = container.read(manualTrackSelectionProvider);

    expect(submitted, isTrue);
    expect(client.catalogCalls, 1);
    expect(client.updateCalls, 1);
    expect(client.lastSessionId, 'session_abc123');
    expect(client.lastTrackId, 'gt7_watkins_glen_international');
    expect(client.lastLayoutId, 'full_course');
    expect(state.appliedTrackId, 'gt7_watkins_glen_international');
    expect(state.appliedLayoutId, 'full_course');
    expect(state.detectedTrackId, 'detected_track_id');
    expect(state.detectedLayoutId, 'detected_layout_id');
    expect(state.appliedSelectionLabel, 'Watkins Glen International · Full Course');
  });

  test('rejects invalid track/layout pairs before submit', () async {
    final client = _FakeManualTrackClient()
      ..catalogResponse = const TrackLayoutsCatalogResponse(
        tracks: [
          TrackCatalogTrack(
            trackId: 'track_a',
            trackName: 'Track A',
            layouts: [TrackCatalogLayout(layoutId: 'layout_a')],
          ),
          TrackCatalogTrack(
            trackId: 'track_b',
            trackName: 'Track B',
            layouts: [TrackCatalogLayout(layoutId: 'layout_b')],
          ),
        ],
      );
    final container = _container(
      syncState: const BackendSyncState(
        sessionId: 'local_123',
        backendSessionId: 'session_abc123',
      ),
      client: client,
    );
    addTearDown(container.dispose);

    final notifier = container.read(manualTrackSelectionProvider.notifier);
    await notifier.loadCatalog();
    notifier
      ..selectTrack('track_a')
      ..selectLayout('layout_b');

    final submitted = await notifier.submitSelection();
    final state = container.read(manualTrackSelectionProvider);

    expect(submitted, isFalse);
    expect(client.updateCalls, 0);
    expect(state.actionErrorMessage,
        'That layout does not belong to the selected track.');
  });

  test('rebinding to a new backend session resets catalog state', () async {
    final client = _FakeManualTrackClient();
    final syncNotifier = _MockSyncNotifier(
      const BackendSyncState(
        sessionId: 'local_123',
        backendSessionId: 'session_abc123',
        alignmentStatus: SessionAlignmentStatus.created,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        backendClientProvider.overrideWithValue(client),
        backendSyncProvider.overrideWith((ref) => syncNotifier),
      ],
    );
    addTearDown(container.dispose);

    await container.read(manualTrackSelectionProvider.notifier).loadCatalog();
    expect(container.read(manualTrackSelectionProvider).hasCatalog, isTrue);

    syncNotifier.update(
      const BackendSyncState(
        sessionId: 'local_999',
        backendSessionId: 'session_xyz999',
        alignmentStatus: SessionAlignmentStatus.created,
      ),
    );

    final state = container.read(manualTrackSelectionProvider);
    expect(state.sessionId, 'session_xyz999');
    expect(state.hasCatalog, isFalse);
    expect(state.phase, ManualTrackSelectionPhase.idle);
  });
}
