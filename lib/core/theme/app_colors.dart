import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2B6EF6);
  static const Color primaryLight = Color(0xFF5A8EFF);
  static const Color primaryDark = Color(0xFF1F52B9);

  static const Color secondary = Color(0xFF1A1A1A);
  static const Color accent = Color(0xFFFF8A3D);

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFF1F3F6);
  static const Color stroke = Color(0xFFE1E5EC);
  static const Color error = Color(0xFFFF5252);
  static const Color success = Color(0xFF1E9E66);

  static const Color textPrimary = Color(0xFF12161F);
  static const Color textSecondary = Color(0xFF616A7C);
  static const Color greyLight = Color(0xFFEEEEEE);
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF171A20);
  static const Color darkSurfaceAlt = Color(0xFF1E222B);
  static const Color darkStroke = Color(0xFF2C3340);

  static const Gradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2B6EF6), Color(0xFF1D3056)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Gradient bgGradient = LinearGradient(
    colors: [Color(0xFFF7F8FA), Color(0xFFF1F3F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const Gradient darkBgGradient = LinearGradient(
    colors: [Color(0xFF0F1115), Color(0xFF12151B), Color(0xFF161A22)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
