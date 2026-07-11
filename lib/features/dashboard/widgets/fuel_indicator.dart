import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Vertical fuel gauge with estimated laps and remaining fuel.
class FuelIndicator extends ConsumerWidget {
  const FuelIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fuelPct = ref.watch(currentFuelProvider);
    final fuelLiters = ref.watch(currentFuelProviderRaw);
    final capacity = ref.watch(fuelCapacityProvider);

    final estLaps = fuelLiters > 0
        ? (fuelLiters / 1.8).clamp(0.0, 99.0)
        : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 220 || constraints.maxWidth < 200;

        return Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FUEL',
                      style: AppTypography.inter(
                        size: compact ? 11 : 12,
                        color: AppColors.neonCyan,
                        letterSpacing: 1.8,
                        weight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Row(
                      children: [
                        Icon(
                          Icons.local_gas_station_rounded,
                          color: AppColors.success,
                          size: compact ? 22 : 28,
                        ),
                        SizedBox(width: compact ? 6 : 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${fuelLiters.toStringAsFixed(1)} L',
                              style: AppTypography.orbitron(
                                size: compact ? 22 : 28,
                                weight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: AppColors.darkSurface,
                    ),
                    SizedBox(height: compact ? 8 : 12),
                    Text(
                      'EST. LAPS',
                      style: AppTypography.inter(
                        size: compact ? 9 : 10,
                        color: AppColors.neonCyan,
                        letterSpacing: 1.3,
                        weight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        estLaps.toStringAsFixed(1),
                        style: AppTypography.orbitron(
                          size: compact ? 20 : 24,
                          weight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (capacity > 0)
                      Text(
                        'CAP ${capacity.toStringAsFixed(0)} L',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.inter(
                          size: compact ? 9 : 10,
                          color: AppColors.textSecondary,
                          weight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: compact ? 10 : 16),
              Expanded(
                flex: 9,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'F',
                      style: AppTypography.orbitron(
                        size: compact ? 14 : 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(width: compact ? 6 : 8),
                    Container(
                      width: compact ? 32 : 40,
                      decoration: BoxDecoration(
                        color: AppColors.carbonBlack,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.darkSurface, width: 0.75),
                      ),
                      padding: EdgeInsets.all(compact ? 2 : 3),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final activeHeight = constraints.maxHeight * (fuelPct / 100);

                          return Stack(
                            children: [
                              Column(
                                children: List.generate(16, (index) {
                                  return Expanded(
                                    child: Container(
                                      margin: EdgeInsets.only(bottom: index < 15 ? 2 : 0),
                                      decoration: BoxDecoration(
                                        color: AppColors.graphite,
                                        borderRadius: BorderRadius.circular(1),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: activeHeight,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.rpmRed,
                                        AppColors.rpmOrange,
                                        AppColors.rpmYellow,
                                        AppColors.success,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    SizedBox(width: compact ? 6 : 8),
                    Text(
                      'E',
                      style: AppTypography.orbitron(
                        size: compact ? 14 : 16,
                        color: AppColors.textSecondary,
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
}
