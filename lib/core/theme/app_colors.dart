import 'package:flutter/material.dart';

class AppColors {
  // Primary - Electric Blue (Modern, Fast, Premium)
  static const Color primary = Color(0xFF0F62FE); // Blue 800
  static const Color primaryLight = Color(0xFF4A8BFF); // Blue 300
  static const Color primaryDark = Color(0xFF063B9C); // Blue 900

  // Accent - Elegant Green (Success, Visibility)
  static const Color accent = Color(0xFF00B050); // Action successful
  static const Color accentDark = Color(0xFF00823B); 

  // Backgrounds
  static const Color background = Color(0xFFF4F7F6); // Light Grey
  static const Color surface = Colors.white;
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text
  static const Color textPrimary = Color(0xFF0A0A0A); // Near Black
  static const Color textSecondary = Color(0xFF6C757D); // Grey 600
  static const Color textLight = Colors.white;

  // Status
  static const Color success = Color(0xFF00B050);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFB8C00);
  static const Color dividerColor = Color(0xFFE5E7EB);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F62FE), Color(0xFF063B9C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white, Color(0xFFF4F7F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
