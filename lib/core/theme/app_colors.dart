import 'package:flutter/material.dart';

class AppColors {
  // Light Background & Surfaces (Clean White Target Aesthetic)
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF8FAFC);
  static const Color boardBackground = Color(0xFFFFFFFF);
  static const Color gridDot = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);

  // Brand Accents
  static const Color primary = Color(0xFF2563EB); // Royal Blue
  static const Color secondary = Color(0xFF7C3AED); // Purple
  static const Color accent = Color(0xFFF59E0B); // Amber / Yellow

  // Dark Navy Arrow Paths (Matching Reference Screenshots)
  static const Color arrowNavy = Color(0xFF0B192C); // Deep Dark Navy
  static const Color arrowDefault = Color(0xFF0B192C);

  // Hearts Life System
  static const Color heartActive = Color(0xFFEF4444); // Radiant Red
  static const Color heartEmpty = Color(0xFFCBD5E1); // Slate Grey Empty

  // Status & Feedback
  static const Color blocked = Color(0xFFEF4444); // Red Blocked Alert
  static const Color blockerAlert = Color(0xFFF97316); // Orange Blocker
  static const Color blockerGlow = Color(0x33EF4444);
  static const Color hint = Color(0xFFF59E0B); // Gold / Amber
  static const Color hintGlow = Color(0x44F59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color scanner = Color(0xFF7C3AED); // Path Scanner violet
  static const Color warning = Color(0xFFF59E0B);
  static const Color pageBackground = Color(0xFFEEF2F7); // Profile/list pages
  static const Color dailyBlue = Color(0xFF1677E8);
  static const Color weeklyOrange = Color(0xFFEA7317);

  // Colorful Arrow Path Palette (Maintained for backward compatibility)
  static const List<Color> arrowColors = [
    Color(0xFF0B192C), // Deep Navy (Primary)
    Color(0xFF1E293B), // Slate Navy
    Color(0xFF334155), // Steel Navy
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFF0D9488), // Teal
    Color(0xFF16A34A), // Green
    Color(0xFF2563EB), // Blue
    Color(0xFFDB2777), // Pink
  ];

  // Typography
  static const Color textPrimary = Color(0xFF0F172A); // Dark Slate
  static const Color textSecondary = Color(0xFF475569); // Slate 600
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400
}

/// Spacing scale (logical pixels).
class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii.
class AppRadii {
  static const double chip = 12;
  static const double button = 26;
  static const double card = 20;
  static const double sheet = 24;
}

/// Shadows used by cards and floating buttons.
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 14, offset: Offset(0, 5)),
  ];
}
