import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/v2_bridge_providers.dart';
import '../providers/session_provider.dart';

/// Compact V2 backend sync status and manual recording override badge.
///
/// Only visible when [BackendConfig.useV2Data] is true (feature flag).
/// Shows sync status, effective session ID, frame counters, and a compact
/// manual recording control that starts/stops local recording and sync.
/// Placed in [HeaderBar] near the sync/status cluster.
class V2SyncBadge extends ConsumerWidget {
  const V2SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v2Enabled = ref.watch(backendV2EnabledProvider);
    if (!v2Enabled) return const SizedBox.shrink();

    final syncState = ref.watch(backendSyncProvider);
    final recordingState = ref.watch(sessionRecorderProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _borderColor(syncState.status), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StatusDot(status: syncState.status),
              const SizedBox(width: 4),
              Text(
                _statusLabel(syncState.status),
                style: AppTypography.inter(
                  size: 9,
                  weight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: _statusColor(syncState.status),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: recordingState.isRecording
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.success.withValues(alpha: 0.12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: recordingState.isRecording
                        ? AppColors.error.withValues(alpha: 0.35)
                        : AppColors.success.withValues(alpha: 0.35),
                    width: 0.75,
                  ),
                ),
                child: InkWell(
                  onTap: () => _toggleRecordingOverride(ref, recordingState),
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          recordingState.isRecording
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 16,
                          color: recordingState.isRecording
                              ? AppColors.error
                              : AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          recordingState.isRecording ? 'STOP' : 'REC',
                          style: AppTypography.inter(
                            size: 9,
                            weight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: recordingState.isRecording
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (syncState.enabled) ...[
            const SizedBox(height: 2),
            Text(
              _shortSessionId(syncState.effectiveSessionId),
              style: AppTypography.inter(
                size: 8,
                weight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              'P:${syncState.pendingFrames} '
              'S:${syncState.totalSent} '
              'A:${syncState.totalAccepted} '
              'R:${syncState.totalRejected}'
              '${syncState.lastRejectionCode != null ? ' ${syncState.lastRejectionCode}' : ''}',
              style: AppTypography.inter(size: 8, color: AppColors.textDim),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _toggleRecordingOverride(
  WidgetRef ref,
  SessionState recordingState,
) async {
  final recorder = ref.read(sessionRecorderProvider.notifier);
  final sync = ref.read(backendSyncProvider.notifier);

  if (recordingState.isRecording) {
    await recorder.stopRecording();
    await sync.setEnabled(false);
    return;
  }

  recorder.startRecording();
  await sync.setEnabled(true);
  unawaited(sync.ensureBackendSession());
}

String syncStatusLabel(SyncStatus status) {
  return switch (status) {
    SyncStatus.disabled => 'OFF',
    SyncStatus.idle => 'IDLE',
    SyncStatus.syncing => 'SYNC',
    SyncStatus.degraded => 'DOWN',
    SyncStatus.rejected => 'REJ',
    SyncStatus.failed => 'FAIL',
  };
}

Color syncStatusColor(SyncStatus status) {
  return switch (status) {
    SyncStatus.disabled => AppColors.textDim,
    SyncStatus.idle => AppColors.success,
    SyncStatus.syncing => AppColors.neonCyan,
    SyncStatus.degraded => AppColors.warning,
    SyncStatus.rejected => AppColors.error,
    SyncStatus.failed => AppColors.error,
  };
}

String _shortSessionId(String id) {
  if (id.length <= 18) return id;
  return '${id.substring(0, 7)}…${id.substring(id.length - 7)}';
}

Color _borderColor(SyncStatus status) {
  if (status == SyncStatus.disabled) return AppColors.darkSurface;
  return syncStatusColor(status).withValues(alpha: 0.2);
}

String _statusLabel(SyncStatus status) => syncStatusLabel(status);
Color _statusColor(SyncStatus status) => syncStatusColor(status);

class _StatusDot extends StatelessWidget {
  final SyncStatus status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _statusColor(status),
      ),
    );
  }
}
