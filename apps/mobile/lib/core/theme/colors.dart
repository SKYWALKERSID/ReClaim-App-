import 'package:flutter/material.dart';

class AppColors {
  // Base Palette (Strict Constraint: #0B0B0F)
  static const Color background = Color(0xFF0B0B0F);
  static const Color surface = Color(0xFF12121A);
  
  // Legacy aliases to fix compiler errors while maintaining new design
  static const Color darkSurface = Color(0xFF12121A);
  static const Color glassBase = Color(0x0DFFFFFF); // 0.05 opacity
  static const Color glassBorder = Color(0x1AFFFFFF); // 0.1 opacity
  
  // Neon Accents (Strict Limit)
  static const Color primary = Color(0xFF8B5CF6); // Purple
  static const Color secondary = Color(0xFF3B82F6); // Blue
  static const Color primaryBlue = Color(0xFF3B82F6); // Alias for legacy code
  static const Color accent = Color(0xFFEC4899); // Pink
  static const Color warning = Color(0xFFF59E0B); // Amber for warnings
  
  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA1A1AA);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
