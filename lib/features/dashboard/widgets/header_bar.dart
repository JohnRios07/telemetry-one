import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Top header bar with logo, live indicator, lap info, and status.
class HeaderBar extends ConsumerStatefulWidget {
  const HeaderBar({super.key});

  @override
  ConsumerState<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends ConsumerState<HeaderBar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lapInfo = ref.watch(lapInfoProvider);
    final data = ref.watch(telemetryDataProvider);
    final isConnected = data != null;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border(
          bottom: BorderSide(color: AppColors.darkSurface, width: 0.75),
        ),
      ),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'TELEMETRY ',
                  style: AppTypography.orbitron(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                TextSpan(
                  text: 'ONE',
                  style: AppTypography.orbitron(
                    size: 18,
                    weight: FontWeight.w700,
                    color: AppColors.neonCyan,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.carbonBlack,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.darkSurface, width: 0.75),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LiveDot(isConnected: isConnected),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: AppTypography.inter(
                    size: 10,
                    color: isConnected ? AppColors.error : AppColors.textDim,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 18),

          _HeaderDivider(),

          const SizedBox(width: 18),

          if (lapInfo.totalLaps > 0)
            Text(
              'LAP ${lapInfo.currentLap} / ${lapInfo.totalLaps}',
              style: AppTypography.orbitron(
                size: 14,
                weight: FontWeight.w600,
                color: AppColors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          if (lapInfo.totalLaps > 0) const SizedBox(width: 18),

          if (lapInfo.totalLaps > 0) _HeaderDivider(),
          if (lapInfo.totalLaps > 0) const SizedBox(width: 18),

          Expanded(
            child: Text(
              'CIRCUIT UNKNOWN',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.inter(
                size: 12,
                color: AppColors.textSecondary,
                weight: FontWeight.w500,
                letterSpacing: 1.1,
              ),
            ),
          ),

          const SizedBox(width: 18),

          Icon(
            Icons.sports_esports_rounded,
            color: isConnected ? AppColors.textPrimary : AppColors.textDim,
            size: 20,
          ),
          const SizedBox(width: 6),
          Text(
            'PS5',
            style: AppTypography.inter(
              size: 12,
              color: isConnected ? AppColors.textPrimary : AppColors.textDim,
              weight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 20),

          Icon(
            Icons.wifi_rounded,
            color: isConnected ? AppColors.textPrimary : AppColors.textDim,
            size: 20,
          ),

          const SizedBox(width: 20),

          Text(
            _formatTime(_now),
            style: AppTypography.orbitron(
              size: 12,
              color: AppColors.textPrimary,
              letterSpacing: 1.1,
            ),
          ),

          const SizedBox(width: 18),

          Icon(
            Icons.settings_rounded,
            color: AppColors.textDim,
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _HeaderDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      color: AppColors.darkSurface,
    );
  }
}

class _LiveDot extends StatefulWidget {
  final bool isConnected;
  const _LiveDot({required this.isConnected});

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isConnected
                ? AppColors.error.withValues(alpha: 0.4 + _controller.value * 0.6)
                : AppColors.textDim,
            boxShadow: widget.isConnected
                ? [
                    BoxShadow(
                      color: AppColors.error
                          .withValues(alpha: 0.3 * _controller.value),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
