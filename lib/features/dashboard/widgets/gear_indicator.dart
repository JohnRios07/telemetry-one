import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Large gear indicator with suggested gear hint.
class GearIndicator extends ConsumerWidget {
  const GearIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gear = ref.watch(currentGearProvider);
    final suggested = ref.watch(suggestedGearProvider);

    String gearStr;
    Color gearColor;

    if (gear <= 0) {
      gearStr = gear == 0 ? 'N' : 'R';
      gearColor = AppColors.warning;
    } else {
      gearStr = '$gear';
      gearColor = AppColors.textPrimary;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          gearStr,
          style: AppTypography.orbitron(
            size: 42,
            weight: FontWeight.w700,
            color: gearColor,
            letterSpacing: 2,
          ),
        ),
        if (suggested > 0 && suggested != gear)
          Text(
            '→ $suggested',
            style: AppTypography.inter(
              size: 11,
              color: AppColors.neonCyan,
              weight: FontWeight.w600,
            ),
          ),
        Text(
          'GEAR',
          style: AppTypography.inter(
            size: 8,
            color: AppColors.textDim,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
