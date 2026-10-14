import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF12141C);
  static const Color bgDeep = Color(0xFF0B0D14);
  static const Color surface = Color(0xFF1C1F2B);
  static const Color surfaceHi = Color(0xFF262A3A);
  static const Color accent = Color(0xFFFF5E7E);
  static const Color violet = Color(0xFFA472EE);
  static const Color gold = Color(0xFFFFC94D);
  static const Color good = Color(0xFF3DDC84);
  static const Color bad = Color(0xFFFF4D4D);
  static const Color textDim = Color(0xFF9AA0B4);

  /// Marka gradyanı (başlık, sürpriz düğmesi).
  static const LinearGradient brand = LinearGradient(
    colors: [accent, violet],
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    // Şeffaf: arka planı [AmbientBackground] çizer (bkz. core/backdrop.dart).
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(surface: AppColors.bg),
  );
}
