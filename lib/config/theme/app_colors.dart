import 'package:flutter/material.dart';

/// Premium motorsport engineering color palette.
///
/// Inspired by SimHub, Formula 1 telemetry, and professional race engineering dashboards.
/// Dark cybernetic theme with neon cyan accents and telemetry orange.
class AppColors {
  AppColors._();

  // ─── Backgrounds ───────────────────────────────────────────────
  /// Deep black — primary background.
  static const Color carbonBlack = Color(0xFF0A0A0A);

  /// Graphite — secondary panels, card surfaces.
  static const Color graphite = Color(0xFF1A1A1A);

  /// Lighter graphite — card backgrounds with depth.
  static const Color darkSurface = Color(0xFF2A2A2A);

  // ─── Accents ────────────────────────────────────────────────────
  /// Neon cyan/turquoise — main accent, highlights, active states.
  static const Color neonCyan = Color(0xFF00D4FF);

  /// Telemetry orange — secondary accent, warnings, brake trace.
  static const Color telemetryOrange = Color(0xFFFF7A00);

  // ─── Status ─────────────────────────────────────────────────────
  /// Green — success, throttle trace, good state.
  static const Color success = Color(0xFF00FF66);

  /// Amber — warning zone.
  static const Color warning = Color(0xFFFFB800);

  /// Red — critical, over-rev, errors.
  static const Color error = Color(0xFFFF2D55);

  // ─── Text ──────────────────────────────────────────────────────
  /// Primary text — bright white.
  static const Color textPrimary = Color(0xFFF5F5F5);

  /// Secondary text — muted gray.
  static const Color textSecondary = Color(0xFF8A8A8A);

  /// Dim text — low priority labels.
  static const Color textDim = Color(0xFF4A4A4A);

  // ─── Graph ──────────────────────────────────────────────────────
  /// Grid lines for telemetry graphs.
  static const Color gridLine = Color(0xFF1A2A2A);

  /// Live indicator pulsing green.
  static const Color liveGreen = Color(0xFF00FF41);

  // ─── Segments for RPM / THR / BRK ──────────────────────────────
  static const Color rpmGreen = Color(0xFF00FF66);
  static const Color rpmYellow = Color(0xFFFFB800);
  static const Color rpmOrange = Color(0xFFFF7A00);
  static const Color rpmRed = Color(0xFFFF2D55);

  // ─── Tire temperatures ─────────────────────────────────────────
  static const Color tireCold = Color(0xFF00AAFF);
  static const Color tireOptimal = Color(0xFF00FF66);
  static const Color tireWarm = Color(0xFFFFB800);
  static const Color tireHot = Color(0xFFFF2D55);
}
