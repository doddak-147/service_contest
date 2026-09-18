import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF3F6F7);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF122229);
  static const textMuted = Color(0xFF52636B);
  static const border = Color(0xFFD4DEE2);
  static const primary = Color(0xFF0E5968);
  static const primaryDark = Color(0xFF073B46);
  static const primarySoft = Color(0xFFE0F1F3);
  static const stress = Color(0xFFB34B3F);
  static const stressSoft = Color(0xFFFFEDEA);
  static const market = Color(0xFF405C9A);
  static const marketSoft = Color(0xFFEDF1FC);
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
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      colorScheme: colorScheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
        suffixStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          borderRadius: BorderRadius.circular(14),
        ),
        filled: true,
        fillColor: AppColors.surface,
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
          fontSize: 28,
          fontWeight: FontWeight.w800,
          height: 1.25,
          letterSpacing: -0.6,
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
