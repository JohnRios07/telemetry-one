import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';

/// Track panel with minimal car position indicator and environmental data.
class TrackPanel extends ConsumerWidget {
  final bool compact;

  const TrackPanel({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carPos = ref.watch(carPositionProvider);

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
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TRACK',
                  style: AppTypography.inter(
                    size: 12,
                    color: AppColors.textPrimary,
                    weight: FontWeight.w600,
                    letterSpacing: 1.6,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Expanded(
                  child: CustomPaint(
                    painter: _TrackPainter(posX: carPos.x, posZ: carPos.z),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 14),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                _envItem('AIR TEMP', '18°C'),
                SizedBox(height: compact ? 8 : 12),
                _envItem('TRACK TEMP', '23°C'),
                SizedBox(height: compact ? 8 : 12),
                _envItem('HUMIDITY', '42%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _envItem(String label, String value) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.carbonBlack,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.darkSurface, width: 0.75),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: AppTypography.inter(
                size: compact ? 9 : 10,
                color: AppColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: compact ? 2 : 4),
            Text(
              value,
              style: AppTypography.orbitron(
                size: compact ? 14 : 18,
                color: AppColors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  final double posX;
  final double posZ;

  _TrackPainter({required this.posX, required this.posZ});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = (size.shortestSide / 2) - 8;

    final framePaint = Paint()
      ..color = AppColors.darkSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    final trackPaint = Paint()
      ..color = AppColors.textPrimary.withValues(alpha: 0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerLinePaint = Paint()
      ..color = AppColors.textDim.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(4),
      ),
      framePaint,
    );

    canvas.drawLine(Offset(8, cy), Offset(size.width - 8, cy), centerLinePaint);

    const scale = 0.002;
    final dx = (posX * scale).clamp(-half * 0.7, half * 0.7).toDouble();
    final dz = (posZ * scale).clamp(-half * 0.7, half * 0.7).toDouble();
    final dotX = cx + dx;
    final dotY = cy + dz;

    final trackPath = Path()
      ..moveTo(cx - half * 0.95, cy - half * 0.15)
      ..cubicTo(
        cx - half * 1.05,
        cy - half * 0.55,
        cx - half * 0.45,
        cy - half * 0.75,
        cx - half * 0.2,
        cy - half * 0.55,
      )
      ..cubicTo(
        cx + half * 0.1,
        cy - half * 0.4,
        cx + half * 0.55,
        cy - half * 0.8,
        cx + half * 0.8,
        cy - half * 0.45,
      )
      ..cubicTo(
        cx + half * 1.0,
        cy - half * 0.15,
        cx + half * 0.55,
        cy - half * 0.05,
        cx + half * 0.45,
        cy + half * 0.15,
      )
      ..cubicTo(
        cx + half * 0.35,
        cy + half * 0.35,
        cx + half * 0.15,
        cy + half * 0.95,
        cx - half * 0.05,
        cy + half * 0.8,
      )
      ..cubicTo(
        cx - half * 0.3,
        cy + half * 0.55,
        cx - half * 0.05,
        cy + half * 0.25,
        cx - half * 0.35,
        cy + half * 0.1,
      )
      ..cubicTo(
        cx - half * 0.7,
        cy,
        cx - half * 0.75,
        cy + half * 0.05,
        cx - half * 0.95,
        cy - half * 0.15,
      );

    canvas.drawPath(trackPath, trackPaint);

    final glowPaint = Paint()
      ..color = AppColors.success.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(dotX, dotY), 5, glowPaint);

    final dotPaint = Paint()
      ..color = AppColors.success
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) {
    return oldDelegate.posX != posX || oldDelegate.posZ != posZ;
  }
}
