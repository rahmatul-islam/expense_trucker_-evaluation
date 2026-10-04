import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primaryPurple = Color(0xFF6C63FF);
  static const Color secondaryPurple = Color(0xFF8E7CFF);
  static const Color accentPink = Color(0xFFFF6B9D);
  static const Color darkBg = Color(0xFF0F0F0F);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color incomeGreen = Color(0xFF2ECC71);
  static const Color expenseRed = Color(0xFFE74C3C);

  // Shadow
  static final BoxShadow primaryShadow = BoxShadow(
    color: primaryPurple.withValues(alpha: 0.3),
    blurRadius: 20,
    offset: const Offset(0, 8),
  );

  static final BoxShadow softShadow = BoxShadow(
    color: Colors.black.withValues(alpha: 0.1),
    blurRadius: 12,
    offset: const Offset(0, 4),
  );

  // Border Radius
  static const double radiusMedium = 16;
  static const double radiusLarge = 24;
  static const double radiusXL = 32;

  // Text Styles
  static const TextStyle headlineXL = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineL = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineM = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  // Gradient
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [primaryPurple, secondaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient darkGradientBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.black.withValues(alpha: 0.9),
      Colors.black.withValues(alpha: 0.5),
      Colors.black.withValues(alpha: 0.95),
    ],
  );
}
