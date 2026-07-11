import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Top-down tire temperature display with 2x2 layout.
///
/// Shows temperatures with color coding:
/// Blue (<60°), Green (60-90°), Yellow (90-100°), Red (>100°)
class TireTemps extends ConsumerWidget {
  final bool compact;

  const TireTemps({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final temps = ref.watch(tireTempsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactMode = compact || constraints.maxHeight < 180;

        return Container(
          padding: EdgeInsets.all(compactMode ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TIRES',
                style: AppTypography.inter(
                  size: compactMode ? 11 : 12,
                  color: AppColors.textPrimary,
                  weight: FontWeight.w600,
                  letterSpacing: 1.6,
                ),
              ),
              SizedBox(height: compactMode ? 6 : 12),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _tireWidget(
                              'FL',
                              temps.isNotEmpty ? temps[0] : 0,
                              compact: compactMode,
                            ),
                          ),
                          SizedBox(height: compactMode ? 6 : 10),
                          Expanded(
                            child: _tireWidget(
                              'RL',
                              temps.length > 2 ? temps[2] : 0,
                              compact: compactMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: compactMode ? 6 : 10),
                    Container(
                      width: compactMode ? 12 : 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: AppColors.carbonBlack,
                        border: Border.all(
                          color: AppColors.darkSurface,
                          width: 0.75,
                        ),
                      ),
                    ),
                    SizedBox(width: compactMode ? 6 : 10),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(
                            child: _tireWidget(
                              'FR',
                              temps.length > 1 ? temps[1] : 0,
                              compact: compactMode,
                            ),
                          ),
                          SizedBox(height: compactMode ? 6 : 10),
                          Expanded(
                            child: _tireWidget(
                              'RR',
                              temps.length > 3 ? temps[3] : 0,
                              compact: compactMode,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tireWidget(String label, double temp, {required bool compact}) {
    final color = _tempColor(temp);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.carbonBlack,
        border: Border.all(color: AppColors.darkSurface, width: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.inter(
              size: compact ? 9 : 10,
              color: AppColors.textSecondary,
              letterSpacing: 1.3,
            ),
          ),
          SizedBox(height: compact ? 4 : 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  temp > 0 ? '${temp.round()}°C' : '--',
                  style: AppTypography.orbitron(
                    size: compact ? 17 : 24,
                    weight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _tempColor(double temp) {
    if (temp <= 0) return AppColors.textDim;
    if (temp < 60) return AppColors.tireCold;
    if (temp < 90) return AppColors.tireOptimal;
    if (temp < 100) return AppColors.tireWarm;
    return AppColors.tireHot;
  }
}
