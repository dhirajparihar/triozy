import 'package:flutter/material.dart';

/// Shared color palette used across Triozy's screens and widgets.
class AppColors {
  // =========================
  // BRAND COLORS
  // =========================
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52E0);
  static const Color primaryLight = Color(0xFF8B7BFF);
  static const Color primaryContainer = Color(0xFFEEF2FF);
  static const Color onPrimaryContainer = Color(0xFF1E1A5C);
  static const Color primaryFixed = Color(0xFFF0EDFF);
  static const Color inversePrimary = Color(0xFFB8B3FF);
  static const Color surfaceTint = primary;

  static const Color secondary = Color(0xFF14B8A6);
  static const Color onSecondary = Colors.white;
  static const Color secondaryContainer = Color(0xFFD9F8F3);
  static const Color onSecondaryContainer = Color(0xFF0F4C45);

  static const Color tertiary = Color(0xFFF97316);
  static const Color onTertiary = Colors.white;
  static const Color tertiaryContainer = Color(0xFFFFEDD5);

  // =========================
  // BACKGROUNDS & SURFACES
  // =========================
  static const Color background = Color(0xFFF8F7FF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFEEF2FF);
  static const Color surfaceDim = Color(0xFFE5E2FF);
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF3F0FF);
  static const Color surfaceContainer = Color(0xFFEEF2FF);
  static const Color surfaceContainerHigh = Color(0xFFEBE8FF);
  static const Color surfaceContainerHighest = Color(0xFFE5E2FF);
  static const Color inverseSurface = Color(0xFF1E1A5C);
  static const Color inverseOnSurface = Color(0xFFF8F7FF);

  // Card backgrounds
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardSoft = Color(0xFFF8F7FF);

  // =========================
  // TEXT COLORS
  // =========================
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);

  // =========================
  // BORDER & DIVIDER
  // =========================
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFEDF1F5);
  static const Color outline = Color(0xFF94A3B8);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // =========================
  // STATUS COLORS
  // =========================
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color onError = Colors.white;
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  // =========================
  // ICON COLORS
  // =========================
  static const Color iconPrimary = primary;
  static const Color iconSecondary = Color(0xFF64748B);

  // =========================
  // BUTTON COLORS
  // =========================
  static const Color buttonPrimary = primary;
  static const Color buttonText = Colors.white;

  static const Color buttonSecondary = Colors.white;
  static const Color buttonSecondaryText = textPrimary;

  // =========================
  // CHIP COLORS
  // =========================
  static const Color chipBackground = Color(0xFFF1F5F9);
  static const Color chipSelected = Color(0xFFEEF2FF);

  // =========================
  // INPUT FIELD COLORS
  // =========================
  static const Color inputBackground = Colors.white;
  static const Color inputBorder = Color(0xFFE2E8F0);
  static const Color inputFocusedBorder = primary;

  // =========================
  // SHADOW
  // =========================
  static const Color shadow = Color(0x14000000);

  // =========================
  // OPTIONAL PREMIUM ACCENTS
  // =========================
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentGreen = Color(0xFF22C55E);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentSoft = Color(0xFFEDE9FE);
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color green50 = Color(0xFFECFDF5);

  // Accent lavender for category cards
  static const Color accentLavender = Color(0xFFEEF2FF);

  // Category card pastel backgrounds
  static const Color pastelBlue = Color(0xFFEFF6FF);
  static const Color pastelPurple = Color(0xFFF0EDFF);
  static const Color pastelMint = Color(0xFFECFDF5);
  static const Color pastelPeach = Color(0xFFFFF7ED);

  // =========================
  // DARK TEXT ON PRIMARY
  // =========================
  static const Color onPrimary = Colors.white;

  // =========================
  // SKELETON / LOADING
  // =========================
  static const Color skeleton = Color(0xFFF1F5F9);

  // =========================
  // GRADIENTS
  // =========================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF6C63FF),
      Color(0xFF8B7BFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
