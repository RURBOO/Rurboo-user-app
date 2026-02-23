import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      
      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: Colors.redAccent,
      ),

      // Typography: Plus Jakarta Sans (Premium, clean sans-serif)
      textTheme: GoogleFonts.plusJakartaSansTextTheme().copyWith(
        displayLarge: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
        displayMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        titleLarge: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        bodyLarge: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary),
        bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
        bodySmall: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
        labelLarge: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),

      // App Bar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),

      // Shadows & Elevation
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.dividerColor, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 20,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary, // Premium solid black button
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.dividerColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.dividerColor, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.dividerColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
      
      // SnackBar
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w500),
      ),
    );
  }
}
