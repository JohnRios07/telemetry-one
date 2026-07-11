import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';

/// Semicircular RPM arc gauge rendered with CustomPainter.
///
/// Draws a 180° arc where the fill progresses from orange to red
/// as RPM approaches the rev limiter. Shows the RPM numeric value
/// in the center of the arc.
class RpmArc extends StatelessWidget {
  final double rpm;
  final double revWarning;
  final double revLimiter;
  final double width;
  final double height;

  const RpmArc({
    super.key,
    required this.rpm,
    required this.revWarning,
    required this.revLimiter,
    this.width = 200,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(width, height),
              painter: _RpmArcPainter(
                rpm: rpm,
                revWarning: revWarning,
                revLimiter: revLimiter,
              ),
            ),
            // RPM value in the center
            Padding(
              padding: EdgeInsets.only(top: height * 0.25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatRpm(rpm),
                    style: AppTypography.orbitron.copyWith(
                      fontSize: height * 0.48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'RPM × 1000',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: height * 0.1,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRpm(double rpm) {
    final kRpm = rpm / 1000.0;
    if (kRpm < 1.0) {
      return kRpm.toStringAsFixed(1);
    }
    return '${kRpm.toStringAsFixed(1)}K';
  }
}

class _RpmArcPainter extends CustomPainter {
  final double rpm;
  final double revWarning;
  final double revLimiter;

  _RpmArcPainter({
    required this.rpm,
    required this.revWarning,
    required this.revLimiter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const startAngle = pi;
    const sweepAngle = pi;
    const strokeWidth = 14.0;

    // Background arc
    final bgPaint = Paint()
      ..color = AppColors.darkSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, bgPaint);

    // Progress arc
    final maxRpm = revLimiter > 0 ? revLimiter : 10000.0;
    final progress = (rpm / maxRpm).clamp(0.0, 1.0);

    if (progress > 0) {
      final warningRatio =
          revLimiter > 0 ? (revWarning / revLimiter).clamp(0.0, 1.0) : 0.8;

      final colors = <Color>[
        AppColors.telemetryOrange,
        AppColors.telemetryOrange,
      ];
      final stops = [0.0, warningRatio];

      if (progress > warningRatio) {
        colors.add(AppColors.warning);
        stops.add(warningRatio / progress);
      }
      if (progress > warningRatio + 0.12) {
        colors.add(AppColors.error);
        stops.add(1.0);
      }

      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: colors,
          stops: stops,
        ).createShader(rect);

      canvas.drawArc(
          rect, startAngle, sweepAngle * progress, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RpmArcPainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.revWarning != revWarning ||
        oldDelegate.revLimiter != revLimiter;
  }
}
