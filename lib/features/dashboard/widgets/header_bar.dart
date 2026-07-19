import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../../core/backend/telemetry_frame_dto.dart';
import '../../../../core/backend/v2_bridge_providers.dart';
import '../providers/manual_track_selection_provider.dart';
import '../../settings/screens/settings_screen.dart';
import '../providers/session_provider.dart';
import '../providers/telemetry_provider.dart';
import 'v2_sync_badge.dart';
import 'manual_track_selection_sheet.dart';

/// Top header bar with logo, live indicator, lap info, and status.
class HeaderBar extends ConsumerStatefulWidget {
  const HeaderBar({super.key});

  @override
  ConsumerState<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends ConsumerState<HeaderBar> {
  late Timer _timer;
  Timer? _trackPollTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _trackPollTimer?.cancel();
    super.dispose();
  }

  void _startTrackPolling() {
    if (_trackPollTimer != null) return;
    _trackPollTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) ref.invalidate(backendTrackDetectionProvider);
      },
    );
  }

  void _stopTrackPolling() {
    _trackPollTimer?.cancel();
    _trackPollTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final lapInfo = ref.watch(lapInfoProvider);
    final data = ref.watch(telemetryDataProvider);
    final position = ref.watch(currentPositionProvider);
    final sessionState = ref.watch(sessionRecorderProvider);
    final isConnected = data != null;
    final manualTrackSelection = ref.watch(manualTrackSelectionProvider);

    final trackDetection = ref.watch(backendTrackDetectionProvider);
    final trackResponse = trackDetection.valueOrNull;

    ref.listen(backendTrackDetectionProvider, (_, next) {
      next.whenOrNull(
        data: (response) {
          if (response?.isPending == true && sessionState.isRecording) {
            _startTrackPolling();
          } else {
            _stopTrackPolling();
          }
        },
      );
    });

    ref.listen(sessionRecorderProvider, (SessionState? prev, SessionState next) {
      final wasRecording = prev?.isRecording ?? false;
      if (!wasRecording && next.isRecording) {
        ref.invalidate(backendTrackDetectionProvider);
      }
    });

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border(
          bottom: BorderSide(color: AppColors.darkSurface, width: 0.75),
        ),
      ),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'TELEMETRY ',
                  style: AppTypography.orbitron(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                TextSpan(
                  text: 'ONE',
                  style: AppTypography.orbitron(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.neonCyan,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.carbonBlack,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.darkSurface, width: 0.75),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveDot(isConnected: isConnected),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: AppTypography.inter(
                    size: 10,
                    color: isConnected ? AppColors.error : AppColors.textDim,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          _HeaderDivider(),

          const SizedBox(width: 18),

          if (lapInfo.totalLaps > 0)
            Text(
              'LAP ${lapInfo.currentLap} / ${lapInfo.totalLaps}',
              style: AppTypography.orbitron(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          if (lapInfo.totalLaps > 0) const SizedBox(width: 18),

          if (position > 0) _HeaderDivider(),
          if (position > 0) const SizedBox(width: 18),
          if (position > 0)
            Text(
              'POS P$position',
              style: AppTypography.orbitron(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          if (position > 0) const SizedBox(width: 18),

          if (lapInfo.totalLaps > 0 || position > 0) _HeaderDivider(),
          if (lapInfo.totalLaps > 0 || position > 0) const SizedBox(width: 18),

          const V2SyncBadge(),

          const SizedBox(width: 12),

          _ManualTrackSelectionButton(state: manualTrackSelection),

          const SizedBox(width: 12),

          if (manualTrackSelection.appliedSelectionLabel != null) ...[
            ManualTrackSelectionBadge(state: manualTrackSelection),
            const SizedBox(width: 12),
          ],

          Expanded(
            child: Text(
              circuitDisplayText(trackResponse, sessionState.isRecording),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.inter(
                size: 12,
                color: AppColors.textSecondary,
                weight: FontWeight.w500,
                letterSpacing: 1.1,
              ),
            ),
          ),

          const SizedBox(width: 18),

          Icon(
            Icons.sports_esports_rounded,
            color: isConnected ? AppColors.textPrimary : AppColors.textDim,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            'PS5',
            style: AppTypography.inter(
              size: 12,
              color: isConnected ? AppColors.textPrimary : AppColors.textDim,
              weight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 20),

          Icon(
            Icons.wifi_rounded,
            color: isConnected ? AppColors.textPrimary : AppColors.textDim,
            size: 20,
          ),

          const SizedBox(width: 20),

          Text(
            _formatTime(_now),
            style: AppTypography.orbitron(
              size: 12,
              color: AppColors.textPrimary,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(width: 18),

          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_rounded, size: 20),
            color: AppColors.textDim,
            tooltip: 'Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }
}

class _ManualTrackSelectionButton extends StatelessWidget {
  final ManualTrackSelectionState state;

  const _ManualTrackSelectionButton({required this.state});

  @override
  Widget build(BuildContext context) {
    final enabled = state.canWrite;
    return TextButton.icon(
      onPressed: enabled
          ? () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const ManualTrackSelectionSheet(),
              );
            }
          : null,
      style: TextButton.styleFrom(
        foregroundColor: enabled ? AppColors.neonCyan : AppColors.textDim,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.alt_route_rounded, size: 16),
      label: Text(
        'MANUAL',
        style: AppTypography.inter(
          size: 10,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
          color: enabled ? AppColors.neonCyan : AppColors.textDim,
        ),
      ),
    );
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 24, color: AppColors.darkSurface);
  }
}

class _LiveDot extends StatefulWidget {
  final bool isConnected;
  const _LiveDot({required this.isConnected});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isConnected
                ? AppColors.error.withValues(
                    alpha: 0.4 + _controller.value * 0.6,
                  )
                : AppColors.textDim,
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: AppColors.error.withValues(
                        alpha: 0.3 * _controller.value,
                      ),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}

<<<<<<< HEAD
class _RecordingControl extends StatelessWidget {
  final SessionState state;
  final VoidCallback onStart;
  final Future<void> Function() onStop;

  const _RecordingControl({
    required this.state,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (state.status) {
        RecordingStatus.idle => _RecordingButton(
          key: const ValueKey<String>('record-idle'),
          label: 'RECORD',
          icon: const _RecordingDot(color: AppColors.error),
          borderColor: AppColors.error.withValues(alpha: 0.28),
          backgroundColor: AppColors.darkSurface,
          onTap: onStart,
        ),
        RecordingStatus.recording => _RecordingButton(
          key: const ValueKey<String>('record-active'),
          label: 'STOP',
          icon: const _RecordingStopIcon(),
          borderColor: AppColors.error.withValues(alpha: 0.4),
          backgroundColor: AppColors.error.withValues(alpha: 0.12),
          onTap: () => unawaited(onStop()),
        ),
        RecordingStatus.saving => const _RecordingSavingButton(
          key: ValueKey<String>('record-saving'),
        ),
      },
    );
  }
}

class _RecordingButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final Color borderColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  const _RecordingButton({
    super.key,
    required this.label,
    required this.icon,
    required this.borderColor,
    required this.backgroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.inter(
                size: 11,
                color: AppColors.textPrimary,
                weight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingSavingButton extends StatelessWidget {
  const _RecordingSavingButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.telemetryOrange,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SAVING',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.textSecondary,
              weight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingDot extends StatelessWidget {
  final Color color;

  const _RecordingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _RecordingStopIcon extends StatelessWidget {
  const _RecordingStopIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}

=======
>>>>>>> bf18288 (fix: remove obsolete engineer header ui)
String circuitDisplayText(TrackDetectionResponse? response, bool hasActiveSession) {
  if (response == null) return 'CIRCUIT UNKNOWN';

  if (response.isDetected) {
    final track = response.trackName?.trim();
    final layout = response.layoutName?.trim();
    final hasTrack = track != null && track.isNotEmpty;
    final hasLayout = layout != null && layout.isNotEmpty;

    if (hasTrack && hasLayout) return '$track · $layout';
    if (hasTrack) return track!;
    if (hasLayout) return layout!;
    return 'CIRCUIT UNKNOWN';
  }

  if (response.isPending && hasActiveSession) return 'Detecting...';

  return 'CIRCUIT UNKNOWN';
}
