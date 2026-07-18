import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../../../core/backend/track_capabilities_dto.dart';

class TrackCapabilitiesPanel extends StatelessWidget {
  final TrackCapabilitiesDto capabilities;
  final bool compact;

  const TrackCapabilitiesPanel({
    super.key,
    required this.capabilities,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = compact || constraints.maxHeight < 150;
        final padding = dense ? 8.0 : 12.0;
        final titleSize = dense ? 9.0 : 11.0;
        final bodySize = dense ? 9.0 : 11.0;

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TRACK CAPABILITIES',
                      style: AppTypography.inter(
                        size: titleSize,
                        color: AppColors.neonCyan,
                        weight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  _StateChip(capabilities: capabilities),
                ],
              ),
              if (capabilities.hasReason) ...[
                SizedBox(height: dense ? 4 : 8),
                Text(
                  capabilities.reason!,
                  maxLines: dense ? 1 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.inter(
                    size: bodySize,
                    height: dense ? 1.15 : 1.25,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StateChip extends StatelessWidget {
  final TrackCapabilitiesDto capabilities;

  const _StateChip({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    final color = switch (capabilities.state) {
      TrackCapabilityState.available => AppColors.success,
      TrackCapabilityState.partial => AppColors.warning,
      TrackCapabilityState.unavailable => AppColors.error,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.75),
      ),
      child: Text(
        capabilities.stateLabel.toUpperCase(),
        style: AppTypography.inter(
          size: 8,
          color: color,
          weight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
