import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../config/theme/app_colors.dart';

/// Top-down car position indicator using GT7 world coordinates.
///
/// Shows the car as a glowing dot on a 2D grid. Since we don't have
/// track layout data, the dot moves relative to its own position
/// history within a bounded viewport.
class Minimap extends StatelessWidget {
  final double posX;
  final double posZ;

  const Minimap({
    super.key,
    required this.posX,
    required this.posZ,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RADAR',
          style: TextStyle(
            color: AppColors.textDim,
            fontSize: 8,
            fontWeight: FontWeight.w400,
            fontFamily: 'Inter',
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        RepaintBoundary(
          child: SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _MinimapPainter(posX: posX, posZ: posZ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MinimapPainter extends CustomPainter {
  final double posX;
  final double posZ;

  _MinimapPainter({required this.posX, required this.posZ});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final half = min(cx, cy) - 2;

    // Background rounded rect
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(4),
    );
    final bgPaint = Paint()
      ..color = AppColors.carbonBlack
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = AppColors.darkSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawRRect(bgRect, borderPaint);

    // Crosshair
    final crossPaint = Paint()
      ..color = AppColors.darkSurface.withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(cx, cy - half), Offset(cx, cy + half), crossPaint);
    canvas.drawLine(Offset(cx - half, cy), Offset(cx + half, cy), crossPaint);

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      half * 0.8,
      crossPaint..style = PaintingStyle.stroke,
    );

    // Scale the world coordinates to the viewport
    // Using a simple scaling factor - the car coordinates are in meters
    // We center the view on the car's current position
    final scale = 0.002; // arbitrary scale to make movement visible
    final dx = (posX * scale).clamp(-half * 0.7, half * 0.7).toDouble();
    final dz = (posZ * scale).clamp(-half * 0.7, half * 0.7).toDouble();

    final dotX = cx + dx;
    final dotY = cy + dz;

    // Car glow
    final glowPaint = Paint()
      ..color = AppColors.telemetryOrange.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(dotX, dotY), 6, glowPaint);

    // Car dot
    final dotPaint = Paint()
      ..color = AppColors.telemetryOrange
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);

    // Direction indicator (small triangle pointing "up" in car's frame)
    // For now just a simple triangle at the dot position
    final dirPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final dirPath = Path()
      ..moveTo(dotX, dotY - 5)
      ..lineTo(dotX - 3, dotY - 1)
      ..lineTo(dotX + 3, dotY - 1)
      ..close();
    canvas.drawPath(dirPath, dirPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimapPainter oldDelegate) {
    return oldDelegate.posX != posX || oldDelegate.posZ != posZ;
  }
}
