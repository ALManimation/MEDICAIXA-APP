import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final baseTheme = ThemeData.light(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        error: AppColors.missed,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displayLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        displayMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displayMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        displaySmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displaySmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineSmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        titleSmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final baseTheme = ThemeData.dark(useMaterial3: true);

    return baseTheme.copyWith(
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        error: AppColors.missed,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displayLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        displayMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displayMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        displaySmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displaySmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        headlineSmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.headlineSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleLarge?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.bold,
          ),
        ),
        titleMedium: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleMedium?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
        titleSmall: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleSmall?.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
