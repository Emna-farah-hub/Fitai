import 'package:flutter/material.dart';

/// Defines the color palette for the FitAI app.
/// Primary brand color is emerald green (#16a34a).
class AppColors {
  AppColors._();

  // Primary Green Palette
  static const Color primary = Color(0xFF16a34a);
  static const Color primaryLight = Color(0xFF22c55e);
  static const Color primaryDark = Color(0xFF15803d);
  static const Color primarySurface = Color(0xFFf0fdf4);
  static const Color primaryBorder = Color(0xFFbbf7d0);

  // Background & Surface
  static const Color background = Color(0xFFfafafa);
  static const Color surface = Color(0xFFffffff);
  static const Color surfaceVariant = Color(0xFFf4f4f5);

  // Text
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6b7280);
  static const Color textMuted = Color(0xFF9ca3af);
  static const Color textOnPrimary = Color(0xFFffffff);

  // Semantic Colors
  static const Color error = Color(0xFFef4444);
  static const Color errorSurface = Color(0xFFfef2f2);
  static const Color warning = Color(0xFFf59e0b);
  static const Color warningSurface = Color(0xFFfffbeb);
  static const Color success = Color(0xFF16a34a);
  static const Color successSurface = Color(0xFFf0fdf4);

  // Border & Divider
  static const Color border = Color(0xFFe5e7eb);
  static const Color divider = Color(0xFFf3f4f6);

  // Shadow
  static const Color shadow = Color(0x0F000000);
  static const Color shadowMedium = Color(0x1A000000);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF16a34a), Color(0xFF15803d)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFf0fdf4), Color(0xFFfafaf9)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF16a34a), Color(0xFF22c55e)],
  );
}
