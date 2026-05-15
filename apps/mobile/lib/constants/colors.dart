import 'package:flutter/material.dart';

class AppColors {
  // --- PREMIUM SOOTHING PASTEL PALETTE ---
  // Warm, organic, and minimalist
  static const Color background = Color(0xFFFAF9F6); // Soft Linen / Off-white
  static const Color surface = Color(0xFFFFFFFF);    // Pure White
  static const Color scaffoldBackground = Color(0xFFFAF9F6); 
  
  static const Color primary = Color(0xFFA8B5A2);    // Muted Sage Green (Soothing)
  static const Color secondary = Color(0xFFD9B4B0);  // Dusty Rose (Warm)
  static const Color accent = Color(0xFFE5D3C3);     // Soft Clay / Sand
  
  static const Color success = Color(0xFFC4D7B2);    // Pale Green
  static const Color warning = Color(0xFFF7E1AE);    // Pale Yellow
  static const Color error = Color(0xFFE8BCBC);      // Pale Coral
  
  static const Color textPrimary = Color(0xFF3D405B);   // Soft Charcoal / Deep Slate
  static const Color textSecondary = Color(0xFF8D99AE); // Muted Blue-Grey
  static const Color textTertiary = Color(0xFFB8C0CC);  // Light Slate

  // Glassmorphism Configs (Soft & Subtle)
  static Color glassBase(BuildContext context) => 
      Colors.white.withOpacity(0.8); 
          
  static Color glassBorder(BuildContext context) => 
      Colors.white.withOpacity(0.5);

  static const LinearGradient happyGradient = LinearGradient(
    colors: [Color(0xFFA8B5A2), Color(0xFFE5D3C3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = happyGradient;
  
  static const Color darkSurface = Color(0xFFFAF9F6); 

  // Subtle Shadows for Depth
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF000000).withOpacity(0.04),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];
}
