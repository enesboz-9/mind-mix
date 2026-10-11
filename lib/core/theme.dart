import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF12141C);
  static const Color surface = Color(0xFF1C1F2B);
  static const Color accent = Color(0xFFFF5E7E);
  static const Color good = Color(0xFF3DDC84);
  static const Color bad = Color(0xFFFF4D4D);
  static const Color textDim = Color(0xFF9AA0B4);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.bg),
  );
}
