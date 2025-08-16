import 'package:flutter/material.dart';

class AppColors {
  static const MaterialColor primary = MaterialColor(
    0xFF3D5AFE,
    <int, Color>{
      50: Color(0xFFE8EAFF),
      100: Color(0xFFC0CCFF),
      200: Color(0xFF94A9FF),
      300: Color(0xFF6885FF),
      400: Color(0xFF4D6AFF),
      500: Color(0xFF3D5AFE),
      600: Color(0xFF3751E8),
      700: Color(0xFF2F45CC),
      800: Color(0xFF273AB3),
      900: Color(0xFF1A2787),
    },
  );

  static const MaterialColor accent = MaterialColor(
    0xFFFF6D00,
    <int, Color>{
      50: Color(0xFFFFF3E0),
      100: Color(0xFFFFE0B2),
      200: Color(0xFFFFCC80),
      300: Color(0xFFFFB74D),
      400: Color(0xFFFFA726),
      500: Color(0xFFFF9800),
      600: Color(0xFFFF8F00),
      700: Color(0xFFFF6D00),
      800: Color(0xFFFF5722),
      900: Color(0xFFE65100),
    },
  );

  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);

  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color darkBackground = Color(0xFF121212);
}

class AppTheme {
  static final light = ThemeData(
    brightness: Brightness.light,
    primarySwatch: AppColors.primary,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.primary),
      titleTextStyle: TextStyle(
        color: AppColors.primary[800],
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),
  );

  static final dark = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: AppColors.primary,
    primaryColor: AppColors.primary,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.primary[300]),
      titleTextStyle: TextStyle(
        color: AppColors.primary[300],
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary[300],
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary[300],
    ),
  );
}