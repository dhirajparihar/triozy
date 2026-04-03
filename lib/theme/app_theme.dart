import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static TextStyle headline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w800,
    Color color = AppColors.onSurface,
    double letterSpacing = -0.5,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.onSurface,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.onSurfaceVariant,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondary,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiary: AppColors.onTertiary,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceTint: AppColors.surfaceTint,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        displayMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        displaySmall: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        headlineLarge: GoogleFonts.manrope(fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        headlineSmall: GoogleFonts.manrope(fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontWeight: FontWeight.w400),
        bodySmall: GoogleFonts.inter(fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
        labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
    );
  }
}
