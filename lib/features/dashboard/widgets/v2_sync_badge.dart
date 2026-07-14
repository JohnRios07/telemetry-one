import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/v2_bridge_providers.dart';

/// Compact V2 backend sync status and toggle badge.
///
/// Only visible when [BackendConfig.useV2Data] is true (feature flag).
/// Shows sync status, enable/disable toggle, effective session ID,
/// and frame counters. Placed in [HeaderBar] near the RECORD/STOP controls.
class V2SyncBadge extends ConsumerWidget {
  const V2SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v2Enabled = ref.watch(backendV2EnabledProvider);
    if (!v2Enabled) return const SizedBox.shrink();

    final syncState = ref.watch(backendSyncProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _borderColor(syncState.status),
          width: 0.5,
        ),
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
              GestureDetector(
                onTap: () =>
                    ref.read(backendSyncProvider.notifier)
                        .setEnabled(!syncState.enabled),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  size: 12,
                  color: syncState.enabled
                      ? AppColors.success
                      : AppColors.textDim,
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
              style: AppTypography.inter(
                size: 8,
                color: AppColors.textDim,
              ),
            ),
          ],
        ],
      ),
    );
  }
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
