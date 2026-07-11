import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Futuristic digital typography for the motorsport dashboard.
///
/// Orbitron for engineering labels and numeric displays.
/// Inter for data labels and body text.
class AppTypography {
  AppTypography._();

  /// Orbitron — futuristic digital display font.
  static const _orbitronFamily = 'Orbitron';

  /// Inter — clean engineering labels.
  static const _interFamily = 'Inter';

  /// Build an Orbitron text style.
  static TextStyle orbitron({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    double height = 1.0,
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: _orbitronFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  /// Build an Inter text style.
  static TextStyle inter({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    double height = 1.2,
    double letterSpacing = 0,
    Color color = AppColors.textSecondary,
  }) {
    return TextStyle(
      fontFamily: _interFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  // ─── Common presets ────────────────────────────────────────────
  /// Engineering label — tiny uppercase labels.
  static TextStyle get labelSmall => inter(size: 8, color: AppColors.textDim);

  /// Data label — slightly larger labels.
  static TextStyle get labelMedium =>
      inter(size: 10, color: AppColors.textSecondary);

  /// Large numeric value.
  static TextStyle get valueLarge => orbitron(
        size: 64,
        weight: FontWeight.w700,
        letterSpacing: 2,
      );

  /// Medium numeric value.
  static TextStyle get valueMedium => orbitron(
        size: 32,
        weight: FontWeight.w600,
        letterSpacing: 1,
      );

  /// Small numeric value.
  static TextStyle get valueSmall => orbitron(
        size: 18,
        weight: FontWeight.w600,
      );
}
