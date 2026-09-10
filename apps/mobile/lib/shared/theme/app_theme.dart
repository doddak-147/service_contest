import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF4F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF122229);
  static const textMuted = Color(0xFF52636B);
  static const border = Color(0xFFD4DEE2);
  static const primary = Color(0xFF0E5968);
  static const danger = Color(0xFFA9342A);
  static const dangerBackground = Color(0xFFFCEDEA);
  static const success = Color(0xFF167345);
  static const successBackground = Color(0xFFE7F6ED);
  static const pending = Color(0xFF7A5C12);
  static const pendingBackground = Color(0xFFFFF6D8);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      surface: AppColors.surface,
    );

    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        scrolledUnderElevation: 0,
      ),
      colorScheme: colorScheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(
          color: AppColors.textMuted,
          fontSize: 14,
          height: 1.45,
        ),
        headlineMedium: TextStyle(
          color: AppColors.text,
          fontSize: 30,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      useMaterial3: true,
    );
  }
}
