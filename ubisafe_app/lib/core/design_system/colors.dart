import 'package:flutter/material.dart';

/// UBISAFE brand palette.
abstract final class AppColors {
  // Primary
  static const Color primary = Color(0xFF1B4F72);
  static const Color primaryLight = Color(0xFF2E86C1);
  static const Color primaryDark = Color(0xFF154360);

  // Secondary / accent
  static const Color accent = Color(0xFFF39C12);
  static const Color accentLight = Color(0xFFF8C471);

  // Semantic
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF2980B9);

  // Neutrals
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
}
