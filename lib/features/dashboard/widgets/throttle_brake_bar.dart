import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Two compact vertical segmented bars for throttle and brake.
///
/// THR — green segments
/// BRK — red segments
/// Each has 14 segments and a percentage label.
class ThrottleBrakeBar extends ConsumerWidget {
  const ThrottleBrakeBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final throttle = ref.watch(currentThrottleProvider);
    final brake = ref.watch(currentBrakeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.graphite,
              border: Border.all(color: AppColors.darkSurface, width: 0.75),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Expanded(child: _bar('THROTTLE', throttle, AppColors.success)),
                const SizedBox(width: 14),
                Expanded(child: _bar('BRAKE', brake, AppColors.error)),
              ],
            ),
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.inter(
            size: 11,
            color: color,
            weight: FontWeight.w600,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _ScaleLabel('100'),
                  _ScaleLabel('50'),
                  _ScaleLabel('0'),
                ],
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 34,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final segHeight =
                        (constraints.maxHeight - (gap * (segments - 1))) /
                            segments;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: List.generate(segments, (i) {
                        final fill = (i + 1) / segments;
                        final isActive = fill <= ratio;

                        return Container(
                          width: double.infinity,
                          height: segHeight,
                          margin: EdgeInsets.only(
                            bottom: i < segments - 1 ? gap : 0,
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
                      }).reversed.toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '${(ratio * 100).round()}',
                style: AppTypography.orbitron(
                  size: 30,
                  weight: FontWeight.w700,
                  color: color,
                ),
              ),
              TextSpan(
                text: '%',
                style: AppTypography.inter(
                  size: 15,
                  color: color,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScaleLabel extends StatelessWidget {
  const _ScaleLabel(this.value);

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: AppTypography.inter(
        size: 10,
        color: AppColors.textDim,
      ),
    );
  }
}
