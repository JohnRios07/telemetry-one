import 'package:flutter/material.dart';
import '../../config/theme/app_typography.dart';

/// Styled HUD label using Orbitron (for data values) or Inter (for descriptions).
class HudLabel extends StatelessWidget {
  final String label;
  final String? value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final TextAlign? textAlign;
  final MainAxisAlignment mainAxisAlignment;

  const HudLabel({
    super.key,
    required this.label,
    this.value,
    this.labelStyle,
    this.valueStyle,
    this.textAlign,
    this.mainAxisAlignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: mainAxisAlignment,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value ?? '--',
          style: valueStyle ?? AppTypography.dataValue,
          textAlign: textAlign ?? TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: labelStyle ?? AppTypography.labelMedium,
          textAlign: textAlign ?? TextAlign.center,
        ),
      ],
    );
  }
}
