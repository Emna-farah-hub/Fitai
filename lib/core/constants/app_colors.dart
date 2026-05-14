import 'package:flutter/material.dart';

/// Defines the color palette for the FitAI app.
/// Primary brand color is emerald green (#16A34A).
class AppColors {
  AppColors._();

  // Core brand
  static const Color primary = Color(0xFF16A34A);
  static const Color primaryLight = Color(0xFF22C55E);
  static const Color primaryDark = Color(0xFF15803D);
  static const Color primarySoft = Color(0xFFDCFCE7);
  static const Color primarySurface = Color(0xFFF0FDF4);
  static const Color primaryBorder = Color(0xFFBEE8CB);
  static const Color primaryWarm = Color(0xFF16A34A);

  // Neutrals
  static const Color background = Color(0xFFF7FBF8);
  static const Color backgroundAlt = Color(0xFFF1F6F3);
  static const Color backgroundSoft = background;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FBF9);
  static const Color surfaceVariant = backgroundAlt;
  static const Color surfaceFloat = surface;
  static const Color surfaceTint = primarySurface;

  // Text
  static const Color textPrimary = Color(0xFF18261D);
  static const Color textSecondary = Color(0xFF667A6E);
  static const Color textMuted = Color(0xFF98A79F);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Support accents
  static const Color tealDark = Color(0xFF2B7A86);
  static const Color teal = Color(0xFF2F8F9D);
  static const Color tealLight = Color(0xFF49AAB8);
  static const Color amberDark = Color(0xFFD99A22);
  static const Color amber = Color(0xFFF2B441);
  static const Color amberSoft = Color(0xFFFEF3C7);
  static const Color sageDark = Color(0xFF5F7F69);
  static const Color sage = Color(0xFF84A98C);
  static const Color sageSoft = Color(0xFFE4F0E7);

  // Semantic colors
  static const Color success = primary;
  static const Color successSurface = primarySurface;
  static const Color warning = amber;
  static const Color warningSurface = Color(0xFFFFFBEB);
  static const Color error = Color(0xFFD94F45);
  static const Color errorSurface = Color(0xFFFEF2F2);
  static const Color info = teal;
  static const Color infoSurface = Color(0xFFF1FAFB);

  // Border & Divider
  static const Color border = Color(0xFFD9E3DD);
  static const Color divider = Color(0xFFECF2EE);

  // Shadow
  static const Color shadow = Color(0x0F000000);
  static const Color shadowMedium = Color(0x1A000000);
  static const Color cardShadow = Color(0x14316643);
  static const Color midnight = Color(0xFF18261D);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primaryDark],
  );

  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealLight, teal],
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF6C65B), amberDark],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primarySurface, Color(0xFFFAFAF9)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryLight, primaryDark],
  );

  // Macro tracking colors
  static const Color macroProtein = teal;
  static const Color macroCarbs = amber;
  static const Color macroFats = Color(0xFF8FA14A);

  // Glycemic indicator colors
  static const Color glycemicGreen = primaryLight;
  static const Color glycemicOrange = amber;
  static const Color glycemicRed = error;

  // Streak
  static const Color streak = amber;
  static const Color streakSurface = warningSurface;

  // Chart colors
  static const Color chartBlue = teal;
  static const Color chartPurple = sage;
  static const Color chartPrimary = primary;
  static const Color chartSecondary = teal;
  static const Color chartTertiary = amber;
  static const Color chartQuaternary = sage;

  // Meal section colors
  static const Color mealBreakfast = amber;
  static const Color mealLunch = primary;
  static const Color mealDinner = teal;
  static const Color mealSnack = sage;

  // Legacy names kept for compatibility
  static const Color cream = Color(0xFFFEFCE8);
  static const Color blush = Color(0xFFFCE7F3);
}
