import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../config/theme/app_typography.dart';
import '../providers/telemetry_provider.dart';
import '../providers/track_history_buffer.dart';

class PlayerTrackMap extends ConsumerWidget {
  const PlayerTrackMap({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(trackHistoryProvider);
    final points = history.points;
    final hasEnoughPoints = points.length >= 3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 180 || constraints.maxWidth < 280;

        return Container(
          padding: EdgeInsets.all(compact ? 10 : 14),
          decoration: BoxDecoration(
            color: AppColors.graphite,
            border: Border.all(color: AppColors.darkSurface, width: 0.75),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'TRACK MAP',
                    style: AppTypography.inter(
                      size: compact ? 11 : 12,
                      color: AppColors.neonCyan,
                      weight: FontWeight.w600,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    hasEnoughPoints ? 'PLAYER LINE' : 'BUFFERING',
                    style: AppTypography.inter(
                      size: compact ? 8 : 9,
                      color: hasEnoughPoints ? AppColors.textSecondary : AppColors.warning,
                      weight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    color: AppColors.carbonBlack,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _PlayerTrackMapPainter(points: points),
                            size: Size.infinite,
                          ),
                        ),
                        if (!hasEnoughPoints)
                          Center(
                            child: Text(
                              'TRACK MAP BUILDING...',
                              style: AppTypography.inter(
                                size: compact ? 10 : 11,
                                color: AppColors.textSecondary,
                                weight: FontWeight.w600,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                'LIVE GT7 PLAYER POSITION HISTORY · X/Z ONLY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.inter(
                  size: compact ? 7 : 8,
                  color: AppColors.textDim,
                  weight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayerTrackMapPainter extends CustomPainter {
  final List<TrackHistoryPoint> points;

  const _PlayerTrackMapPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    _paintBackground(canvas, rect);

    const inset = 14.0;
    final drawRect = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - (inset * 2)),
      math.max(0, size.height - (inset * 2)),
    );

    if (drawRect.width <= 0 || drawRect.height <= 0) return;

    _paintGrid(canvas, drawRect);

    if (points.length < 2) return;

    double minX = points.first.x;
    double maxX = points.first.x;
    double minZ = points.first.z;
    double maxZ = points.first.z;

    for (final point in points.skip(1)) {
      minX = math.min(minX, point.x);
      maxX = math.max(maxX, point.x);
      minZ = math.min(minZ, point.z);
      maxZ = math.max(maxZ, point.z);
    }

    final spanX = math.max(maxX - minX, 1.0);
    final spanZ = math.max(maxZ - minZ, 1.0);
    final scale = math.min(drawRect.width / spanX, drawRect.height / spanZ);
    final contentWidth = spanX * scale;
    final contentHeight = spanZ * scale;
    final offsetX = drawRect.left + (drawRect.width - contentWidth) / 2;
    final offsetY = drawRect.top + (drawRect.height - contentHeight) / 2;

    Offset project(TrackHistoryPoint point) {
      final dx = (point.x - minX) * scale;
      final dz = (point.z - minZ) * scale;
      return Offset(offsetX + dx, offsetY + dz);
    }

    final path = Path();
    final projected = points.map(project).toList(growable: false);

    path.moveTo(projected.first.dx, projected.first.dy);
    for (final point in projected.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final glowPaint = Paint()
      ..color = AppColors.neonCyan.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [AppColors.neonCyan, AppColors.success],
      ).createShader(drawRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    final currentPoint = projected.last;
    final markerGlow = Paint()
      ..color = AppColors.telemetryOrange.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final markerFill = Paint()..color = AppColors.telemetryOrange;
    final markerCore = Paint()..color = AppColors.textPrimary;

    canvas.drawCircle(currentPoint, 10, markerGlow);
    canvas.drawCircle(currentPoint, 5.5, markerFill);
    canvas.drawCircle(currentPoint, 2.2, markerCore);
  }

  void _paintBackground(Canvas canvas, Rect rect) {
    final borderPaint = Paint()
      ..color = AppColors.darkSurface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    canvas.drawRect(rect.deflate(0.375), borderPaint);
  }

  void _paintGrid(Canvas canvas, Rect rect) {
    final gridPaint = Paint()
      ..color = AppColors.gridLine.withValues(alpha: 0.85)
      ..strokeWidth = 0.5;

    for (int row = 0; row <= 4; row++) {
      final y = rect.top + (rect.height / 4) * row;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), gridPaint);
    }

    for (int col = 0; col <= 4; col++) {
      final x = rect.left + (rect.width / 4) * col;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PlayerTrackMapPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
