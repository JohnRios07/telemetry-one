import 'package:flutter/material.dart';
import '../../config/theme/app_colors.dart';

/// Styled HUD panel container with graphite background and thin border.
class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double minHeight;

  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.minHeight = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.graphite,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.darkSurface,
          width: 0.5,
        ),
      ),
      padding: padding,
      constraints: BoxConstraints(minHeight: minHeight),
      child: child,
    );
  }
}
