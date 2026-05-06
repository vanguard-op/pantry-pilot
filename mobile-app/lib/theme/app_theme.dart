import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF2F6B3B);
  static const Color secondary = Color(0xFFA67C52);
  static const Color tertiary = Color(0xFFB86A52);
  static const Color neutral = Color(0xFF182019);
}

class AppRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
}

class AppPadding {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double x2l = 40;
}

final ColorScheme _lightScheme = ColorScheme.fromSeed(
  seedColor: AppColors.primary,
  brightness: Brightness.light,
  surface: const Color(0xFFF6F1E7),
).copyWith(secondary: AppColors.secondary, tertiary: AppColors.tertiary);

final ColorScheme _darkScheme = ColorScheme.fromSeed(
  seedColor: AppColors.primary,
  brightness: Brightness.dark,
).copyWith(secondary: AppColors.secondary, tertiary: AppColors.tertiary);

class AppTheme {
  static ThemeData get lightTheme => _baseTheme(
    _lightScheme,
    scaffoldBackground: const Color(0xFFF9F6F0),
    cardColor: Colors.white,
    navigationBackground: Colors.white,
  );

  static ThemeData get darkTheme => _baseTheme(
    _darkScheme,
    scaffoldBackground: const Color(0xFF101512),
    cardColor: _darkScheme.surfaceContainerHigh,
    navigationBackground: AppColors.neutral,
  );
}

ThemeData _baseTheme(
  ColorScheme scheme, {
  required Color scaffoldBackground,
  required Color cardColor,
  required Color navigationBackground,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: scheme.primary,
      titleTextStyle: GoogleFonts.epilogue(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: scheme.primary,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline.withAlpha(160)),
        textStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppPadding.md,
        vertical: AppPadding.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withAlpha(155)),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navigationBackground,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return GoogleFonts.manrope(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
          fontSize: 12,
        );
      }),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.secondaryContainer,
      labelStyle: GoogleFonts.manrope(
        color: scheme.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: GoogleFonts.manrope(color: scheme.onInverseSurface),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.epilogue(
        fontSize: 46,
        fontWeight: FontWeight.w900,
        letterSpacing: -2,
      ),
      displayMedium: GoogleFonts.epilogue(
        fontSize: 30,
        fontWeight: FontWeight.w700,
      ),
      displaySmall: GoogleFonts.epilogue(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineLarge: GoogleFonts.epilogue(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: GoogleFonts.epilogue(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: GoogleFonts.epilogue(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: GoogleFonts.manrope(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      bodyMedium: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: GoogleFonts.manrope(
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}
