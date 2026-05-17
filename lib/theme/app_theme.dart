import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Shared theme helpers and the app's light Material 3 theme.
class AppTheme {
  static const double pageMargin = 20;
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;

  /// Typography helper for headings and prominent titles.
  static TextStyle headline({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.onSurface,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.publicSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? _headlineTracking(fontSize),
      height: height,
    );
  }

  /// Typography helper for body copy and paragraphs.
  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color color = AppColors.onSurface,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height ?? 1.5,
    );
  }

  /// Typography helper for compact labels and metadata.
  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.onSurfaceVariant,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing ?? 0.45,
      height: height ?? 1.3,
    );
  }

  /// Typography helper for button text.
  static TextStyle button({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color color = AppColors.onPrimary,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: 1.3,
    );
  }

  /// Standard rounded-corner helper used by cards and sheets.
  static BorderRadius radius([double value = radiusMd]) {
    return BorderRadius.circular(value);
  }

  /// Shared shadow preset for elevated cards and surfaces.
  static List<BoxShadow> shadow({
    double blur = 28,
    double offsetY = 12,
    double alpha = 0.08,
  }) {
    return [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: alpha),
        blurRadius: blur,
        offset: Offset(0, offsetY),
      ),
    ];
  }

  /// Reusable card decoration with border and shadow defaults.
  static BoxDecoration cardDecoration({
    Color color = AppColors.surfaceContainerLowest,
    double radiusValue = radiusMd,
    Border? border,
    double shadowAlpha = 0.07,
    double blur = 24,
    double offsetY = 10,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radiusValue),
      border:
          border ??
          Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.22)),
      boxShadow: shadow(blur: blur, offsetY: offsetY, alpha: shadowAlpha),
    );
  }

  /// Material 3 light theme configured with the Triozy palette.
  static ThemeData get lightTheme {
    final colorScheme =
        const ColorScheme.light(
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
    ).copyWith(
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
          surfaceContainerHigh: AppColors.surfaceContainerHigh,
          surfaceContainerHighest: AppColors.surfaceContainerHighest,
          surfaceBright: AppColors.surfaceBright,
          surfaceDim: AppColors.surfaceDim,
        );

    final textTheme = GoogleFonts.manropeTextTheme().copyWith(
      displayLarge: headline(fontSize: 40, fontWeight: FontWeight.w700),
      displayMedium: headline(fontSize: 32, fontWeight: FontWeight.w700),
      displaySmall: headline(fontSize: 28, fontWeight: FontWeight.w700),
      headlineLarge: headline(fontSize: 32, fontWeight: FontWeight.w700),
      headlineMedium: headline(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: headline(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: body(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: body(fontSize: 16, fontWeight: FontWeight.w700),
      titleSmall: body(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: body(fontSize: 18),
      bodyMedium: body(fontSize: 16),
      bodySmall: body(fontSize: 14),
      labelLarge: label(fontSize: 14),
      labelMedium: label(fontSize: 12),
      labelSmall: label(fontSize: 11),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      splashColor: AppColors.primary.withValues(alpha: 0.05),
      highlightColor: Colors.transparent,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: headline(fontSize: 24, fontWeight: FontWeight.w700),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        modalBackgroundColor: AppColors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: body(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.inverseOnSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        hintStyle: body(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.slate500,
        ),
        labelStyle: label(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurfaceVariant,
        ),
        prefixIconColor: AppColors.slate500,
        suffixIconColor: AppColors.slate500,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(
          color: AppColors.primaryContainer,
          width: 1.35,
        ),
        errorBorder: _inputBorder(color: AppColors.error),
        focusedErrorBorder: _inputBorder(color: AppColors.error, width: 1.35),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: button(fontSize: 14, color: AppColors.primary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          side: BorderSide(
            color: AppColors.outlineVariant.withValues(alpha: 0.42),
          ),
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: button(fontSize: 14, color: AppColors.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: button(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: button(),
        ),
      ),
    );
  }

  static double _headlineTracking(double fontSize) {
    if (fontSize >= 30) {
      return -0.6;
    }
    if (fontSize >= 24) {
      return -0.2;
    }
    return 0.15;
  }

  static OutlineInputBorder _inputBorder({
    Color color = AppColors.outlineVariant,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: BorderSide(
        color: color.withValues(
          alpha: color == AppColors.outlineVariant ? 0.42 : 1,
        ),
        width: width,
      ),
    );
  }
}
