import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Horizontal segmented RPM bar with shift-light colors.
///
/// Segments: green → yellow → orange → red by RPM ratio.
/// 20 segments total, 3px gaps, 12px height.
class RpmBar extends ConsumerWidget {
  final bool compact;

  const RpmBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revInfo = ref.watch(revInfoProvider);
    final ratio = revInfo.ratio;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 12 : 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const segments = 20;
              const gap = 2.0;
              final segWidth =
                  (constraints.maxWidth - (gap * (segments - 1))) / segments;

              return Row(
                children: List.generate(segments, (i) {
                  final fill = (i + 1) / segments;
                  final isActive = fill <= ratio;
                  Color color;

                  if (fill <= 0.4) {
                    color = AppColors.rpmGreen;
                  } else if (fill <= 0.7) {
                    color = AppColors.rpmYellow;
                  } else if (fill <= 0.85) {
                    color = AppColors.rpmOrange;
                  } else {
                    color = AppColors.rpmRed;
                  }

                  return Container(
                    width: segWidth,
                    height: compact ? 10 : 12,
                    margin: EdgeInsets.only(right: i < segments - 1 ? gap : 0),
                    decoration: BoxDecoration(
                      color: isActive ? color : AppColors.darkSurface,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        SizedBox(height: compact ? 1 : 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              revInfo.rpm.toStringAsFixed(0),
              style: AppTypography.orbitron(
                size: compact ? 9 : 10,
                color: AppColors.textSecondary,
              ),
            ),
            if (revInfo.revLimiter > 0)
              Text(
                revInfo.revLimiter.toStringAsFixed(0),
                style: AppTypography.inter(
                  size: compact ? 7 : 8,
                  color: AppColors.textDim,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
