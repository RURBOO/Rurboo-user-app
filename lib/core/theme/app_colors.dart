import 'package:flutter/material.dart';

class AppColors {
  // Primary - Deep Emerald (Trust, Growth, Rural)
  static const Color primary = Color(0xFF00695C); // Teal 800
  static const Color primaryLight = Color(0xFF4DB6AC); // Teal 300
  static const Color primaryDark = Color(0xFF004D40); // Teal 900

  // Accent - Amber (Visibility, Action)
  static const Color accent = Color(0xFFFFC107); // Amber
  static const Color accentDark = Color(0xFFFFA000); // Amber 700

  // Backgrounds
  static const Color background = Color(0xFFF5F7FA); // Light Grey-Blue (Premium Surface)
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A); // Near Black
  static const Color textSecondary = Color(0xFF757575); // Grey 600
  static const Color textLight = Colors.white;

  // Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFB8C00);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00695C), Color(0xFF004D40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFFAFAFA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
