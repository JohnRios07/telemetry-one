import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/backend_sync_provider.dart';
import '../../../../core/backend/v2_bridge_providers.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/session_provider.dart';
import '../providers/telemetry_provider.dart';
import '../widgets/header_bar.dart';
import '../widgets/telemetry_graph.dart';
import '../widgets/rpm_bar.dart';
import '../widgets/throttle_brake_bar.dart';
import '../widgets/lap_times.dart';
import '../widgets/fuel_indicator.dart';
import '../widgets/player_track_map.dart';
import '../widgets/race_engineer_panel.dart';
import '../widgets/tire_temps.dart';

/// Landscape dashboard with strong visual hierarchy inspired by motorsport pits.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    ref.listenManual<TelemetryData?>(
      telemetryDataProvider,
      (_, data) {
        if (data == null) return;
        ref.read(telemetryBufferProvider.notifier).add(data.throttle, data.brake);
        ref.read(trackHistoryProvider.notifier).ingest(data);
        ref.read(sessionRecorderProvider.notifier).recordPoint(data);
        ref.read(backendSyncProvider.notifier).recordData(data);
      },
      fireImmediately: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.carbonBlack,
      body: Column(
        children: [
          const HeaderBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final shortLayout = constraints.maxHeight < 610;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    children: [
                      Expanded(flex: shortLayout ? 40 : 44, child: _buildTopRow()),
                      const SizedBox(height: 10),
                      Expanded(flex: shortLayout ? 31 : 30, child: _buildMiddleRow()),
                      const SizedBox(height: 10),
                      Expanded(flex: shortLayout ? 29 : 26, child: _buildBottomRow()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopRow() {
    return Row(
      children: [
        const Expanded(flex: 78, child: TelemetryGraph()),
        const SizedBox(width: 10),
        const Expanded(flex: 22, child: FuelIndicator()),
      ],
    );
  }

  Widget _buildMiddleRow() {
    return Row(
      children: [
        const Expanded(flex: 21, child: ThrottleBrakeBar()),
        const SizedBox(width: 10),
        const Expanded(flex: 43, child: _SpeedClusterCard()),
        const SizedBox(width: 10),
        const Expanded(flex: 36, child: LapTimesPanel()),
      ],
    );
  }

  Widget _buildBottomRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 210;
        final v2Enabled = ref.watch(backendV2EnabledProvider);

        return Row(
          children: [
            Expanded(flex: 42, child: TireTemps(compact: compact)),
            const SizedBox(width: 10),
            if (v2Enabled) ...[
              const Expanded(flex: 28, child: PlayerTrackMap()),
              const SizedBox(width: 10),
              const Expanded(flex: 30, child: RaceEngineerPanel(compact: true)),
            ] else
              const Expanded(flex: 58, child: PlayerTrackMap()),
          ],
        );
      },
    );
  }
}

class _SpeedClusterCard extends ConsumerWidget {
  const _SpeedClusterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(currentSpeedProvider);
    final gear = ref.watch(currentGearProvider);
    final rpm = ref.watch(currentRpmProvider);

    final gearLabel = gear < 0
        ? 'R'
        : gear == 0
        ? 'N'
        : '$gear';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 220;
        final panelPadding = compact ? 10.0 : 14.0;
        final sectionGap = compact ? 10.0 : 16.0;
        final speedLabelSize = compact ? 11.0 : 12.0;
        final speedUnitSize = compact ? 15.0 : 18.0;
        final gearValueSize = compact ? 60.0 : 72.0;
        final rpmValueSize = compact ? 24.0 : 28.0;
        final rpmLabelSize = compact ? 10.0 : 11.0;

        return Container(
          padding: EdgeInsets.all(panelPadding),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 60,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPEED',
                      style: AppTypography.inter(
                        size: speedLabelSize,
                        color: AppColors.neonCyan,
                        weight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            speed.toStringAsFixed(0),
                            style: AppTypography.orbitron(
                              size: compact ? 88 : 104,
                              weight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'KM/H',
                        style: AppTypography.inter(
                          size: speedUnitSize,
                          color: AppColors.textSecondary,
                          letterSpacing: compact ? 1.8 : 2.2,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 10),
                    Text(
                      'RPM',
                      style: AppTypography.inter(
                        size: rpmLabelSize,
                        color: AppColors.neonCyan,
                        weight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        rpm.toStringAsFixed(0),
                        style: AppTypography.orbitron(
                          size: rpmValueSize,
                          weight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 6),
                    RpmBar(compact: compact),
                    SizedBox(height: compact ? 8 : 10),
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.neonCyan.withValues(alpha: 0.2),
                            AppColors.neonCyan.withValues(alpha: 0.55),
                            AppColors.neonCyan.withValues(alpha: 0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                margin: EdgeInsets.symmetric(horizontal: sectionGap),
                color: AppColors.darkSurface,
              ),
              Expanded(
                flex: 40,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GEAR',
                      style: AppTypography.inter(
                        size: speedLabelSize,
                        color: AppColors.neonCyan,
                        weight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                    SizedBox(height: compact ? 6 : 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              gearLabel,
                              style: AppTypography.orbitron(
                                size: gearValueSize,
                                weight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(height: compact ? 2 : 4),
                          Text(
                            'CURRENT RATIO',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.inter(
                              size: compact ? 10 : 11,
                              color: AppColors.textDim,
                              weight: FontWeight.w400,
                              letterSpacing: 1.1,
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
}
