import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Compact lap times panel showing current, best, last lap and delta.
class LapTimesPanel extends ConsumerWidget {
  const LapTimesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lapInfo = ref.watch(lapInfoProvider);
    final hasLiveLapTime = lapInfo.currentLapTime != null;
    final hasDelta = lapInfo.deltaTime != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.darkSurface, width: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'LAP TIMES',
            style: AppTypography.inter(
              size: 10,
              color: AppColors.neonCyan,
              weight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _timeCard(
                          'LAP TIME',
                          _fmt(lapInfo.currentLapTime),
                          hasLiveLapTime
                              ? AppColors.textPrimary
                              : AppColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _deltaCard(lapInfo.deltaTime, hasDelta: hasDelta),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: _timeCard(
                          'BEST LAP',
                          _fmt(lapInfo.bestLapTime),
                          AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _timeCard(
                          'LAST LAP',
                          _fmt(lapInfo.lastLapTime),
                          AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasLiveLapTime
                ? 'LIVE LAP TIMER ACTIVE'
                : 'LIVE LAP TIMER NOT AVAILABLE FROM CURRENT FEED',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.inter(
              size: 8,
              color: hasLiveLapTime ? AppColors.success : AppColors.textDim,
              weight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
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
              size: 9,
              color: AppColors.neonCyan,
              weight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTypography.orbitron(
                size: 26,
                weight: FontWeight.w700,
                color: color,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deltaCard(Duration? delta, {required bool hasDelta}) {
    if (delta == null) {
      return _timeCard('DELTA', '--:--.---', hasDelta ? AppColors.textPrimary : AppColors.textDim);
    }

    final isFaster = delta.isNegative;
    final absDelta = delta.isNegative ? -delta : delta;
    final sign = isFaster ? '-' : '+';
    final color = isFaster ? AppColors.success : AppColors.error;

    final minutes = absDelta.inMinutes.remainder(60);
    final seconds = absDelta.inSeconds.remainder(60);
    final millis = absDelta.inMilliseconds.remainder(1000);

    String value;
    if (minutes > 0) {
      value = '$sign$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
    } else {
      value = '$sign$seconds.${millis.toString().padLeft(3, '0')}';
    }

    return _timeCard('DELTA', value, color);
  }

  String _fmt(Duration? d) {
    if (d == null) return '--:--.---';
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final millis = d.inMilliseconds.remainder(1000);
    return '$minutes:${seconds.toString().padLeft(2, '0')}.${millis.toString().padLeft(3, '0')}';
  }
}
