import 'package:flutter/material.dart';

/// Horizontal shift light bar rendered with CustomPainter.
///
/// 12 LED segments with real-world shift light colors:
/// - Green  (LEDs 1-6):   safe zone
/// - Yellow (LEDs 7-9):   prepare to shift
/// - Orange (LEDs 10-11): warning
/// - Red    (LED 12):     shift NOW / rev limiter
class ShiftLights extends StatelessWidget {
  final double rpm;
  final double revWarning;
  final double revLimiter;

  const ShiftLights({
    super.key,
    required this.rpm,
    required this.revWarning,
    required this.revLimiter,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: double.infinity,
        height: 24,
        child: CustomPaint(
          painter: _ShiftLightsPainter(
            rpm: rpm,
            revWarning: revWarning,
            revLimiter: revLimiter,
          ),
        ),
      ),
    );
  }
}

class _ShiftLightsPainter extends CustomPainter {
  static const int ledCount = 12;

  static const _green = Color(0xFF2ED573);
  static const _yellow = Color(0xFFFFD93D);
  static const _orange = Color(0xFFFF8A00);
  static const _red = Color(0xFFFF3B30);
  static const _off = Color(0xFF1A1A1A);

  // Color per LED index (0-based)
  static const List<Color> _ledColors = [
    _green, _green, _green, _green, _green, _green,
    _yellow, _yellow, _yellow,
    _orange, _orange,
    _red,
  ];

  final double rpm;
  final double revWarning;
  final double revLimiter;

  _ShiftLightsPainter({
    required this.rpm,
    required this.revWarning,
    required this.revLimiter,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRpm = revLimiter > 0 ? revLimiter : 10000.0;
    final ratio = (rpm / maxRpm).clamp(0.0, 1.0);

    final ledWidth = (size.width - (ledCount - 1) * 2) / ledCount;
    final ledHeight = size.height * 0.7;
    final yOffset = (size.height - ledHeight) / 2;
    final cornerRadius = ledHeight * 0.3;

    final ledsOn = (ratio * ledCount).ceil().clamp(0, ledCount);

    final offPaint = Paint()
      ..color = _off
      ..style = PaintingStyle.fill;

    for (int i = 0; i < ledCount; i++) {
      final x = i * (ledWidth + 2);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, yOffset, ledWidth, ledHeight),
        Radius.circular(cornerRadius),
      );

      if (i >= ledsOn) {
        canvas.drawRRect(rrect, offPaint);
      } else {
        final onPaint = Paint()
          ..color = _ledColors[i]
          ..style = PaintingStyle.fill;

        // Glow effect for last 3 LEDs when active
        if (i >= ledCount - 3 && ledWidth > 8) {
          final glowPaint = Paint()
            ..color = _ledColors[i].withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 2, yOffset - 2, ledWidth + 4, ledHeight + 4),
              Radius.circular(cornerRadius + 2),
            ),
            glowPaint,
          );
        }

        canvas.drawRRect(rrect, onPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShiftLightsPainter oldDelegate) {
    return oldDelegate.rpm != rpm ||
        oldDelegate.revWarning != revWarning ||
        oldDelegate.revLimiter != revLimiter;
  }
}
