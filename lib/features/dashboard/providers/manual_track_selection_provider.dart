import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/backend_client.dart';
import '../../../core/backend/backend_sync_provider.dart';
import '../../../core/backend/track_capabilities_dto.dart';
import '../../../core/backend/track_layout_dto.dart';

enum ManualTrackSelectionPhase { idle, loadingCatalog, ready, submitting, failed }

class ManualTrackSelectionState {
  final String sessionId;
  final String? backendSessionId;
  final ManualTrackSelectionPhase phase;
  final List<TrackCatalogTrack> catalog;
  final String? selectedTrackId;
  final String? selectedLayoutId;
  final String? appliedTrackId;
  final String? appliedLayoutId;
  final String? detectedTrackId;
  final String? detectedLayoutId;
  final TrackCapabilitiesDto? appliedCapabilities;
  final String? catalogErrorMessage;
  final String? actionErrorMessage;

  const ManualTrackSelectionState({
    required this.sessionId,
    required this.backendSessionId,
    this.phase = ManualTrackSelectionPhase.idle,
    this.catalog = const [],
    this.selectedTrackId,
    this.selectedLayoutId,
    this.appliedTrackId,
    this.appliedLayoutId,
    this.detectedTrackId,
    this.detectedLayoutId,
    this.appliedCapabilities,
    this.catalogErrorMessage,
    this.actionErrorMessage,
  });

  bool get canWrite => backendSessionId != null;
  bool get hasCatalog => catalog.isNotEmpty;
  bool get isLoading => phase == ManualTrackSelectionPhase.loadingCatalog;
  bool get isSubmitting => phase == ManualTrackSelectionPhase.submitting;
  bool get isBusy => isLoading || isSubmitting;
  bool get hasSelection => selectedTrackId != null && selectedLayoutId != null;
  bool get hasAppliedSelection =>
      appliedTrackId != null && appliedLayoutId != null;

  String get unavailableMessage =>
      backendSessionId == null
          ? 'Awaiting aligned backend session.'
          : 'Manual selection unavailable.';

  TrackCatalogTrack? trackFor(String? trackId) {
    if (trackId == null) return null;
    for (final track in catalog) {
      if (track.trackId == trackId) return track;
    }
    return null;
  }

  TrackCatalogTrack? get selectedTrack => trackFor(selectedTrackId);
  TrackCatalogLayout? get selectedLayout =>
      selectedTrack?.layoutFor(selectedLayoutId);
  TrackCatalogTrack? get appliedTrack => trackFor(appliedTrackId);
  TrackCatalogLayout? get appliedLayout => appliedTrack?.layoutFor(appliedLayoutId);

  bool get isSelectedPairValid {
    final track = selectedTrack;
    final layoutId = selectedLayoutId;
    if (track == null || layoutId == null) return false;
    return track.layoutFor(layoutId) != null;
  }

  bool get canConfirm => canWrite && hasSelection && isSelectedPairValid && !isBusy;

  String? get appliedSelectionLabel {
    if (!hasAppliedSelection) return null;

    final trackLabel = appliedTrack?.displayName ?? appliedTrackId;
    final layoutLabel = appliedLayout?.displayName ?? appliedLayoutId;
    if (trackLabel == null && layoutLabel == null) return null;
    if (trackLabel == null) return layoutLabel;
    if (layoutLabel == null) return trackLabel;
    return '$trackLabel · $layoutLabel';
  }

  ManualTrackSelectionState copyWith({
    Object? sessionId = _unset,
    Object? backendSessionId = _unset,
    ManualTrackSelectionPhase? phase,
    List<TrackCatalogTrack>? catalog,
    Object? selectedTrackId = _unset,
    Object? selectedLayoutId = _unset,
    Object? appliedTrackId = _unset,
    Object? appliedLayoutId = _unset,
    Object? detectedTrackId = _unset,
    Object? detectedLayoutId = _unset,
    Object? appliedCapabilities = _unset,
    Object? catalogErrorMessage = _unset,
    Object? actionErrorMessage = _unset,
  }) {
    return ManualTrackSelectionState(
      sessionId: sessionId == _unset ? this.sessionId : sessionId as String,
      backendSessionId: backendSessionId == _unset
          ? this.backendSessionId
          : backendSessionId as String?,
      phase: phase ?? this.phase,
      catalog: catalog ?? this.catalog,
      selectedTrackId: selectedTrackId == _unset
          ? this.selectedTrackId
          : selectedTrackId as String?,
      selectedLayoutId: selectedLayoutId == _unset
          ? this.selectedLayoutId
          : selectedLayoutId as String?,
      appliedTrackId: appliedTrackId == _unset
          ? this.appliedTrackId
          : appliedTrackId as String?,
      appliedLayoutId: appliedLayoutId == _unset
          ? this.appliedLayoutId
          : appliedLayoutId as String?,
      detectedTrackId: detectedTrackId == _unset
          ? this.detectedTrackId
          : detectedTrackId as String?,
      detectedLayoutId: detectedLayoutId == _unset
          ? this.detectedLayoutId
          : detectedLayoutId as String?,
      appliedCapabilities: appliedCapabilities == _unset
          ? this.appliedCapabilities
          : appliedCapabilities as TrackCapabilitiesDto?,
      catalogErrorMessage: catalogErrorMessage == _unset
          ? this.catalogErrorMessage
          : catalogErrorMessage as String?,
      actionErrorMessage: actionErrorMessage == _unset
          ? this.actionErrorMessage
          : actionErrorMessage as String?,
    );
  }
}

const _unset = Object();

class ManualTrackSelectionNotifier extends StateNotifier<ManualTrackSelectionState> {
  final BackendClient _client;

  ManualTrackSelectionNotifier({
    required BackendClient client,
    required String sessionId,
    required String? backendSessionId,
  }) : _client = client,
       super(
         ManualTrackSelectionState(
           sessionId: sessionId,
           backendSessionId: backendSessionId,
         ),
       );

  Future<void> loadCatalog({bool force = false}) async {
    if (!force && state.hasCatalog && state.phase != ManualTrackSelectionPhase.failed) {
      return;
    }

    if (!state.canWrite) {
      state = state.copyWith(
        phase: ManualTrackSelectionPhase.failed,
        catalogErrorMessage: state.unavailableMessage,
        actionErrorMessage: null,
      );
      return;
    }

    state = state.copyWith(
      phase: ManualTrackSelectionPhase.loadingCatalog,
      catalogErrorMessage: null,
      actionErrorMessage: null,
    );

    try {
      final response = await _client.getTrackLayouts();
      final catalog = List<TrackCatalogTrack>.unmodifiable(response.tracks);
      final selectedTrackId =
          _trackIsAvailable(state.selectedTrackId, catalog)
              ? state.selectedTrackId
              : null;
      final selectedLayoutId =
          _layoutIsAvailable(selectedTrackId, state.selectedLayoutId, catalog)
              ? state.selectedLayoutId
              : null;
      final appliedTrackId =
          _trackIsAvailable(state.appliedTrackId, catalog)
              ? state.appliedTrackId
              : null;
      final appliedLayoutId =
          _layoutIsAvailable(appliedTrackId, state.appliedLayoutId, catalog)
              ? state.appliedLayoutId
              : null;

      state = state.copyWith(
        phase: ManualTrackSelectionPhase.ready,
        catalog: catalog,
        selectedTrackId: selectedTrackId,
        selectedLayoutId: selectedLayoutId,
        appliedTrackId: appliedTrackId,
        appliedLayoutId: appliedLayoutId,
      );
    } on BackendRequestException catch (e) {
      state = state.copyWith(
        phase: ManualTrackSelectionPhase.failed,
        catalogErrorMessage: e.error.message,
      );
    } catch (e) {
      state = state.copyWith(
        phase: ManualTrackSelectionPhase.failed,
        catalogErrorMessage: 'Failed to load track/layout catalog: $e',
      );
    }
  }

  void selectTrack(String trackId) {
    if (!state.canWrite) return;
    state = state.copyWith(
      selectedTrackId: trackId,
      selectedLayoutId: null,
      actionErrorMessage: null,
    );
  }

  void selectLayout(String layoutId) {
    if (!state.canWrite) return;
    state = state.copyWith(
      selectedLayoutId: layoutId,
      actionErrorMessage: null,
    );
  }

  Future<bool> submitSelection() async {
    if (!state.canWrite) {
      state = state.copyWith(
        actionErrorMessage: state.unavailableMessage,
      );
      return false;
    }

    final trackId = state.selectedTrackId;
    final layoutId = state.selectedLayoutId;
    final track = state.selectedTrack;
    if (trackId == null || layoutId == null || track == null) {
      state = state.copyWith(
        actionErrorMessage: 'Choose a track and a layout before confirming.',
      );
      return false;
    }

    if (track.layoutFor(layoutId) == null) {
      state = state.copyWith(
        actionErrorMessage: 'That layout does not belong to the selected track.',
      );
      return false;
    }

    state = state.copyWith(
      phase: ManualTrackSelectionPhase.submitting,
      actionErrorMessage: null,
    );

    try {
      final response = await _client.updateSessionTrackLayout(
        state.backendSessionId!,
        trackId,
        layoutId,
      );

      state = state.copyWith(
        phase: ManualTrackSelectionPhase.ready,
        appliedTrackId: response.trackId,
        appliedLayoutId: response.layoutId,
        appliedCapabilities: response.capabilities,
        detectedTrackId: response.detectedTrackId,
        detectedLayoutId: response.detectedLayoutId,
        selectedTrackId: response.trackId,
        selectedLayoutId: response.layoutId,
        actionErrorMessage: null,
      );
      return true;
    } on BackendRequestException catch (e) {
      state = state.copyWith(
        phase: ManualTrackSelectionPhase.ready,
        actionErrorMessage: e.error.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        phase: ManualTrackSelectionPhase.ready,
        actionErrorMessage: 'Failed to update track/layout: $e',
      );
      return false;
    }
  }

  bool _trackIsAvailable(String? trackId, List<TrackCatalogTrack> catalog) {
    if (trackId == null) return false;
    return catalog.any((track) => track.trackId == trackId);
  }

  bool _layoutIsAvailable(
    String? trackId,
    String? layoutId,
    List<TrackCatalogTrack> catalog,
  ) {
    if (trackId == null || layoutId == null) return false;
    TrackCatalogTrack? track;
    for (final item in catalog) {
      if (item.trackId == trackId) {
        track = item;
        break;
      }
    }
    return track?.layoutFor(layoutId) != null;
  }
}

final manualTrackSelectionProvider =
    StateNotifierProvider.autoDispose<ManualTrackSelectionNotifier, ManualTrackSelectionState>(
      (ref) {
        final client = ref.watch(backendClientProvider);
        final binding = ref.watch(
          backendSyncProvider.select(
            (state) => (
              sessionId: state.effectiveSessionId,
              backendSessionId: state.backendSessionId,
            ),
          ),
        );

        return ManualTrackSelectionNotifier(
          client: client,
          sessionId: binding.sessionId,
          backendSessionId: binding.backendSessionId,
        );
      },
    );
