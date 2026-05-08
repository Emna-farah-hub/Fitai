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

  // Macro tracking colors
  static const Color macroProtein = Color(0xFF6366f1);  // indigo
  static const Color macroCarbs = Color(0xFFf97316);     // orange
  static const Color macroFats = Color(0xFFeab308);      // yellow

  // Glycemic indicator colors
  static const Color glycemicGreen = Color(0xFF22c55e);
  static const Color glycemicOrange = Color(0xFFf97316);
  static const Color glycemicRed = Color(0xFFef4444);

  // Streak
  static const Color streak = Color(0xFFf59e0b);         // amber/gold
  static const Color streakSurface = Color(0xFFfffbeb);

  // Chart colors
  static const Color chartBlue = Color(0xFF3B82F6);
  static const Color chartPurple = Color(0xFF8B5CF6);

  // Meal section colors
  static const Color mealBreakfast = Color(0xFFF97316); // orange
  static const Color mealLunch = Color(0xFF16A34A);     // green
  static const Color mealDinner = Color(0xFF3B82F6);    // blue
  static const Color mealSnack = Color(0xFF8B5CF6);     // purple

  // Upgraded primary - slightly warmer green
  static const Color primaryWarm = Color(0xFF12A35A);

  // New semantic palette
  static const Color sage = Color(0xFF84A98C);
  static const Color cream = Color(0xFFFEFCE8);
  static const Color blush = Color(0xFFFCE7F3);
  static const Color midnight = Color(0xFF0F1923);

  // Improved card shadow (colored, not pure black)
  static const Color cardShadow = Color(0x14169A4A); // green-tinted shadow

  // Better surface colors
  static const Color surfaceFloat = Color(0xFFFFFFFF);   // Level 1 cards
  static const Color surfaceTint = Color(0xFFF0FDF4);    // Level 2 cards

  // Soft background (replacing plain #fafafa)
  static const Color backgroundSoft = Color(0xFFF7FBF8); // warm mint white

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
