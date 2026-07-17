import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../core/backend/track_layout_dto.dart';
import '../providers/manual_track_selection_provider.dart';

class ManualTrackSelectionBadge extends StatelessWidget {
  final ManualTrackSelectionState state;

  const ManualTrackSelectionBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final label = state.appliedSelectionLabel;
    if (label == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'MANUAL',
            style: AppTypography.inter(
              size: 9,
              weight: FontWeight.w700,
              color: AppColors.neonCyan,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              size: 9,
              color: AppColors.textSecondary,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ManualTrackSelectionSheet extends ConsumerStatefulWidget {
  const ManualTrackSelectionSheet({super.key});

  @override
  ConsumerState<ManualTrackSelectionSheet> createState() =>
      _ManualTrackSelectionSheetState();
}

class _ManualTrackSelectionSheetState
    extends ConsumerState<ManualTrackSelectionSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(manualTrackSelectionProvider.notifier).loadCatalog());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(manualTrackSelectionProvider);
    final controller = ref.read(manualTrackSelectionProvider.notifier);
    final isLoadingPlaceholder =
        state.phase == ManualTrackSelectionPhase.idle &&
        state.catalog.isEmpty &&
        state.catalogErrorMessage == null;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Material(
        color: AppColors.graphite,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Manual Track Selection',
                        style: AppTypography.orbitron(
                          size: 16,
                          weight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'Close',
                      color: AppColors.textDim,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  state.canWrite
                      ? 'Pick a track, then a layout, and confirm the override.'
                      : state.unavailableMessage,
                  style: AppTypography.inter(
                    size: 11,
                    height: 1.3,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (state.catalogErrorMessage != null ||
                    state.actionErrorMessage != null) ...[
                  const SizedBox(height: 10),
                  _ErrorBanner(
                    message:
                        state.catalogErrorMessage ?? state.actionErrorMessage!,
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    child: _buildBody(
                      context,
                      state,
                      controller,
                      isLoadingPlaceholder,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: state.canConfirm
                          ? () async {
                              final ok = await controller.submitSelection();
                              if (ok && context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          : null,
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Apply'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ManualTrackSelectionState state,
    ManualTrackSelectionNotifier controller,
    bool isLoadingPlaceholder,
  ) {
    if (state.phase == ManualTrackSelectionPhase.loadingCatalog ||
        isLoadingPlaceholder) {
      return const Center(
        key: ValueKey('manual-track-loading'),
        child: CircularProgressIndicator(),
      );
    }

    if (state.phase == ManualTrackSelectionPhase.failed && !state.hasCatalog) {
      return _EmptyState(
        title: 'Could not load track catalog',
        message:
            state.catalogErrorMessage ??
            'The backend catalog is unavailable right now.',
        actionLabel: 'Retry',
        onAction: () => controller.loadCatalog(force: true),
      );
    }

    if (state.catalog.isEmpty) {
      return const _EmptyState(
        title: 'No tracks available',
        message: 'The backend returned an empty track/layout catalog.',
      );
    }

    final selectedTrack = state.selectedTrack;
    final layouts = selectedTrack?.layouts ?? const <TrackCatalogLayout>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Track',
          style: AppTypography.inter(
            size: 10,
            weight: FontWeight.w700,
            color: AppColors.textDim,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: _TrackList(
            tracks: state.catalog,
            selectedTrackId: state.selectedTrackId,
            onSelect: controller.selectTrack,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Layout',
          style: AppTypography.inter(
            size: 10,
            weight: FontWeight.w700,
            color: AppColors.textDim,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: selectedTrack == null
              ? const _EmptyState(
                  title: 'Select a track',
                  message: 'Choose a track to reveal its layouts.',
                )
              : layouts.isEmpty
              ? const _EmptyState(
                  title: 'No layouts for this track',
                  message: 'Pick a different track to see its layouts.',
                )
              : _LayoutList(
                  layouts: layouts,
                  selectedLayoutId: state.selectedLayoutId,
                  onSelect: controller.selectLayout,
                ),
        ),
      ],
    );
  }
}

class _TrackList extends StatelessWidget {
  final List<TrackCatalogTrack> tracks;
  final String? selectedTrackId;
  final ValueChanged<String> onSelect;

  const _TrackList({
    required this.tracks,
    required this.selectedTrackId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: tracks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final selected = track.trackId == selectedTrackId;
        return InkWell(
          onTap: () => onSelect(track.trackId),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? AppColors.darkSurface : AppColors.carbonBlack,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected ? AppColors.neonCyan : AppColors.darkSurface,
                width: 0.75,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: track.trackId,
                  groupValue: selectedTrackId,
                  onChanged: (value) => value == null ? null : onSelect(value),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    track.displayName,
                    style: AppTypography.inter(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  track.trackId,
                  style: AppTypography.inter(
                    size: 9,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LayoutList extends StatelessWidget {
  final List<TrackCatalogLayout> layouts;
  final String? selectedLayoutId;
  final ValueChanged<String> onSelect;

  const _LayoutList({
    required this.layouts,
    required this.selectedLayoutId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: layouts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final layout = layouts[index];
        final selected = layout.layoutId == selectedLayoutId;
        return InkWell(
          onTap: () => onSelect(layout.layoutId),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: selected ? AppColors.darkSurface : AppColors.carbonBlack,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: selected ? AppColors.neonCyan : AppColors.darkSurface,
                width: 0.75,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: layout.layoutId,
                  groupValue: selectedLayoutId,
                  onChanged: (value) => value == null ? null : onSelect(value),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    layout.displayName,
                    style: AppTypography.inter(
                      size: 12,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  layout.layoutId,
                  style: AppTypography.inter(
                    size: 9,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        message,
        style: AppTypography.inter(
          size: 10,
          height: 1.3,
          color: AppColors.error,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.inter(
              size: 12,
              weight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.inter(
              size: 10,
              height: 1.3,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
