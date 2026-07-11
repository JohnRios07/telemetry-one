import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Telemetry One dark theme — motorsport engineering aesthetic.
class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.carbonBlack,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.telemetryOrange,
        secondary: AppColors.telemetryOrange,
        surface: AppColors.graphite,
        error: AppColors.error,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.carbonBlack,
        elevation: 0,
      ),
      textTheme: TextTheme(
        displayLarge: AppTypography.orbitron(size: 28, weight: FontWeight.w700),
        displayMedium: AppTypography.orbitron(size: 22, weight: FontWeight.w600),
        bodyLarge: AppTypography.inter(size: 14, color: AppColors.textPrimary),
        bodyMedium: AppTypography.inter(size: 12, color: AppColors.textSecondary),
        bodySmall: AppTypography.inter(size: 10, color: AppColors.textDim),
        labelLarge: AppTypography.orbitron(size: 12, weight: FontWeight.w600),
        labelSmall: AppTypography.inter(size: 9, color: AppColors.textDim),
      ),
      cardTheme: CardThemeData(
        color: AppColors.graphite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkSurface,
        thickness: 1,
      ),
    );
  }
}
