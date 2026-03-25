import 'package:flutter/material.dart';

// ── Legacy dark-mode constants ─────────────────────────────────────────────────
// Kept for backward compatibility with AppTheme (theme.dart). Do not remove.

abstract final class AppColors {
  // Backgrounds
  static const Color backgroundPrimary = Color(0xFF0A0F1E);
  static const Color backgroundSurface = Color(0xFF141B2D);
  static const Color backgroundElevated = Color(0xFF1E2A3A);

  // Accents
  static const Color accentPrimary = Color(0xFF00BCD4);
  static const Color accentHover = Color(0xFF26C6DA);

  // Text
  static const Color textPrimary = Color(0xFFF4F5F7);
  static const Color textSecondary = Color(0xFF8B92A5);
  static const Color textMuted = Color(0xFF4A5568);

  // Semantic
  static const Color destructive = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFD69E2E);
  static const Color success = Color(0xFF38A169);

  // Borders
  static const Color borderSubtle = Color(0xFF2D3748);
}

// ── Theme-aware colour scheme ──────────────────────────────────────────────────
// Access via context.cs — automatically returns light or dark variant.

@immutable
final class AppColorScheme {
  const AppColorScheme({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundElevated,
    required this.borderSubtle,
    required this.borderDefault,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
  });

  final Color backgroundPrimary;

  /// Cards, panels, sidebar, overlays.
  final Color backgroundSecondary;

  /// Elevated surfaces: search fill, chips, placeholders.
  final Color backgroundElevated;

  /// Very subtle dividers and hairlines.
  final Color borderSubtle;

  /// Standard card/input borders.
  final Color borderDefault;

  final Color textPrimary;
  final Color textSecondary;

  /// Hints, timestamps, muted labels.
  final Color textTertiary;

  // ── Brand accents — identical in both modes ──────────────────────────────────
  static const Color accent = Color(0xFF19CBD6);
  static const Color success = Color(0xFF2EA073);
  static const Color warning = Color(0xFFD97D24);
  static const Color destructive = Color(0xFFDC4444);

  // ── Static instances ──────────────────────────────────────────────────────────

  static const AppColorScheme dark = AppColorScheme(
    backgroundPrimary: Color(0xFF0A0F1E),
    backgroundSecondary: Color(0xFF131929),
    backgroundElevated: Color(0xFF1A2332),
    borderSubtle: Color(0xFF232D40),
    borderDefault: Color(0xFF2D3B52),
    textPrimary: Color(0xFFF4F5F7),
    textSecondary: Color(0xFFA8B1C3),
    textTertiary: Color(0xFF6B7689),
  );

  static const AppColorScheme light = AppColorScheme(
    backgroundPrimary: Color(0xFFF4F5F7),
    backgroundSecondary: Color(0xFFFFFFFF),
    backgroundElevated: Color(0xFFE8EBF0),
    borderSubtle: Color(0xFFDFE3EB),
    borderDefault: Color(0xFFC7CDD9),
    textPrimary: Color(0xFF0D1117),
    textSecondary: Color(0xFF4F5663),
    textTertiary: Color(0xFF7D8494),
  );
}

// ── BuildContext extension ─────────────────────────────────────────────────────

extension AppColorSchemeX on BuildContext {
  /// Returns the correct [AppColorScheme] for the current theme brightness.
  AppColorScheme get cs =>
      Theme.of(this).brightness == Brightness.dark
          ? AppColorScheme.dark
          : AppColorScheme.light;
}
