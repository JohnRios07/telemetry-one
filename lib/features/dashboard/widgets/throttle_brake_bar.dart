import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Two compact horizontal segmented bars for throttle and brake.
///
/// THR — green segments
/// BRK — orange segments
/// Each has 10 segments and a percentage label.
class ThrottleBrakeBar extends ConsumerWidget {
  const ThrottleBrakeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final throttle = ref.watch(currentThrottleProvider);
    final brake = ref.watch(currentBrakeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bar('THROTTLE', throttle, AppColors.success),
              const SizedBox(height: 18),
              _bar('BRAKE', brake, AppColors.telemetryOrange),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bar(String label, double value, Color color) {
    final ratio = value.clamp(0.0, 1.0);
    const segments = 14;
    const gap = 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.inter(
            size: 11,
            color: color,
            weight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 78,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${(ratio * 100).round()}',
                      style: AppTypography.orbitron(
                        size: 34,
                        weight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    TextSpan(
                      text: '%',
                      style: AppTypography.inter(
                        size: 16,
                        color: color,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                children: [
                  SizedBox(
                    height: 28,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final segWidth =
                            (constraints.maxWidth - (gap * (segments - 1))) /
                                segments;

                        return Row(
                          children: List.generate(segments, (i) {
                            final fill = (i + 1) / segments;
                            final isActive = fill <= ratio;

                            return Container(
                              width: segWidth,
                              height: 28,
                              margin: EdgeInsets.only(
                                right: i < segments - 1 ? gap : 0,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? color.withValues(alpha: 0.9)
                                    : AppColors.carbonBlack,
                                border: Border.all(
                                  color: isActive
                                      ? color.withValues(alpha: 0.25)
                                      : AppColors.darkSurface,
                                  width: 0.6,
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '0',
                        style: AppTypography.inter(
                          size: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                      Text(
                        '50',
                        style: AppTypography.inter(
                          size: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                      Text(
                        '100',
                        style: AppTypography.inter(
                          size: 10,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
