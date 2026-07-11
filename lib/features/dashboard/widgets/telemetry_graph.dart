import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// MoTeC-style telemetry graph showing throttle (green) and brake (red) traces.
///
/// Scrolling time-series with grid lines, legend, and percentage axis.
class TelemetryGraph extends ConsumerWidget {
  const TelemetryGraph({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buffer = ref.watch(telemetryBufferProvider);
    final throttleData = buffer.throttleTrace;
    final brakeData = buffer.brakeTrace;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        border: Border.all(color: AppColors.darkSurface, width: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'THROTTLE',
                style: AppTypography.inter(
                  size: 11,
                  color: AppColors.success,
                  weight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '&',
                style: AppTypography.inter(
                  size: 11,
                  color: AppColors.textSecondary,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'BRAKE',
                style: AppTypography.inter(
                  size: 11,
                  color: AppColors.error,
                  weight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              _legendLine(AppColors.success),
              const SizedBox(width: 6),
              Text(
                'THROTTLE',
                style: AppTypography.inter(
                  size: 9,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(width: 12),
              _legendLine(AppColors.error),
              const SizedBox(width: 6),
              Text(
                'BRAKE',
                style: AppTypography.inter(
                  size: 9,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GraphPainter(
                  throttleData: throttleData,
                  brakeData: brakeData,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 36, right: 6, top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0s', style: AppTypography.inter(size: 8, color: AppColors.textDim)),
                Text('5s', style: AppTypography.inter(size: 8, color: AppColors.textDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendLine(Color color) {
    return Container(
      width: 22,
      height: 2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final List<double> throttleData;
  final List<double> brakeData;

  _GraphPainter({
    required this.throttleData,
    required this.brakeData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final graphLeft = 24.0;
    const graphTop = 4.0;
    const graphBottom = 12.0;
    final graphWidth = size.width - graphLeft - 4;
    final graphHeight = size.height - graphTop - graphBottom;

    if (graphWidth <= 0 || graphHeight <= 0) return;

    final chartRect = Rect.fromLTWH(graphLeft, graphTop, graphWidth, graphHeight);

    // ─── Grid lines ─────────────────────────────────────────────
    _drawGrid(canvas, chartRect);

    // ─── Data ───────────────────────────────────────────────────
    final count = max(throttleData.length, brakeData.length);
    if (count < 2) return;

    final greenPaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final brakePaint = Paint()
      ..color = AppColors.error.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Throttle trace
    final throttlePath = Path();
    for (int i = 0; i < throttleData.length; i++) {
      final x = graphLeft + (i / max(throttleData.length - 1, 1)) * graphWidth;
      final y = graphTop + graphHeight - (throttleData[i].clamp(0, 1) * graphHeight);
      if (i == 0) {
        throttlePath.moveTo(x, y);
      } else {
        throttlePath.lineTo(x, y);
      }
    }
    canvas.drawPath(throttlePath, greenPaint);

    // Brake trace
    final brakePath = Path();
    for (int i = 0; i < brakeData.length; i++) {
      final x = graphLeft + (i / max(brakeData.length - 1, 1)) * graphWidth;
      final y = graphTop + graphHeight - (brakeData[i].clamp(0, 1) * graphHeight);
      if (i == 0) {
        brakePath.moveTo(x, y);
      } else {
        brakePath.lineTo(x, y);
      }
    }
    canvas.drawPath(brakePath, brakePaint);

    // ─── Y axis labels ─────────────────────────────────────────
    final labelStyle = TextStyle(
      color: AppColors.textDim,
      fontSize: 7,
      fontFamily: 'Inter',
    );

    for (int pct = 0; pct <= 100; pct += 50) {
      final labelPainter = TextPainter(
        text: TextSpan(text: '$pct', style: labelStyle),
        textDirection: TextDirection.ltr,
      );
      labelPainter.layout();
      final y = graphTop + graphHeight * (1 - pct / 100.0) - labelPainter.height / 2;
      labelPainter.paint(canvas, Offset(0, y));
    }
  }

  void _drawGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = AppColors.gridLine
      ..strokeWidth = 0.5;

    // Horizontal grid lines
    for (int pct = 0; pct <= 100; pct += 25) {
      final y = rect.top + rect.height * (1 - pct / 100.0);
      canvas.drawLine(
        Offset(rect.left, y),
        Offset(rect.right, y),
        gridPaint,
      );
    }

    // Vertical grid lines
    for (int i = 0; i <= 5; i++) {
      final x = rect.left + (rect.width / 5) * i;
      canvas.drawLine(
        Offset(x, rect.top),
        Offset(x, rect.bottom),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) => true;
}
