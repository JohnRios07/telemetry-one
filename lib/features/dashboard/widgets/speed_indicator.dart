import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Large clean speed display with km/h label.
class SpeedIndicator extends ConsumerWidget {
  const SpeedIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(currentSpeedProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          speed.toStringAsFixed(0),
          style: AppTypography.orbitron(
            size: 72,
            weight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 80,
          height: 1,
          color: AppColors.neonCyan.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 4),
        Text(
          'km/h',
          style: AppTypography.inter(
            size: 11,
            color: AppColors.textSecondary,
            weight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
