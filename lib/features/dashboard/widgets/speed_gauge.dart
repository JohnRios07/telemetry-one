import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';

/// Futuristic speed display with neon glow effect.
///
/// Shows km/h with a subtle orange glow behind the number.
class SpeedGauge extends StatelessWidget {
  final double speedKmh;

  const SpeedGauge({super.key, required this.speedKmh});

  @override
  Widget build(BuildContext context) {
    final speedText = '${speedKmh.round()}';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Speed number with glow
        Text(
          speedText,
          style: AppTypography.orbitron.copyWith(
            fontSize: 64,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.0,
            shadows: [
              Shadow(
                color: AppColors.telemetryOrange.withValues(alpha: 0.4),
                blurRadius: 20,
              ),
              Shadow(
                color: AppColors.telemetryOrange.withValues(alpha: 0.2),
                blurRadius: 40,
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppColors.telemetryOrange.withValues(alpha: 0.3),
                width: 0.5,
              ),
              bottom: BorderSide(
                color: AppColors.telemetryOrange.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            'KM/H',
            style: AppTypography.orbitron.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.telemetryOrange.withValues(alpha: 0.7),
              letterSpacing: 4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
