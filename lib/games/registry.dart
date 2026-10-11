import 'package:flutter/material.dart';

import '../core/mini_game.dart';
import 'color_match/color_match_screen.dart';
import 'lights_out/lights_out_screen.dart';
import 'math_rush/math_rush_screen.dart';
import 'odd_one_out/odd_one_out_screen.dart';
import 'sequence_echo/sequence_echo_screen.dart';
import 'tap_rush/tap_rush_screen.dart';

/// Ana menüde görünen oyunlar. Yeni oyun eklemek için buraya bir satır ekle.
final List<MiniGame> allGames = [
  MiniGame(
    id: 'color_match',
    nameEn: 'Color Match',
    nameTr: 'Renk Eşle',
    descEn: 'Memorize a color, find its exact twin.',
    descTr: 'Rengi aklında tut, aynısını bul.',
    icon: Icons.palette_rounded,
    color: const Color(0xFFFF5E7E),
    builder: () => const ColorMatchScreen(),
  ),
  MiniGame(
    id: 'odd_one_out',
    nameEn: 'Odd One Out',
    nameTr: 'Farklı Olan',
    descEn: 'Spot the slightly different shade.',
    descTr: 'Biraz farklı tonu yakala.',
    icon: Icons.grid_view_rounded,
    color: const Color(0xFF4D9DFF),
    builder: () => const OddOneOutScreen(),
  ),
  MiniGame(
    id: 'sequence_echo',
    nameEn: 'Sequence Echo',
    nameTr: 'Sıra Hafızası',
    descEn: 'Watch the pattern, repeat it.',
    descTr: 'Sırayı izle, tekrar et.',
    icon: Icons.graphic_eq_rounded,
    color: const Color(0xFF3DDC84),
    builder: () => const SequenceEchoScreen(),
  ),
  MiniGame(
    id: 'math_rush',
    nameEn: 'Math Rush',
    nameTr: 'Hızlı İşlem',
    descEn: 'Solve quick sums before time runs out.',
    descTr: 'Süre bitmeden işlemleri çöz.',
    icon: Icons.calculate_rounded,
    color: const Color(0xFFA472EE),
    builder: () => const MathRushScreen(),
  ),
  MiniGame(
    id: 'lights_out',
    nameEn: 'Lights Out',
    nameTr: 'Işıkları Söndür',
    descEn: 'Turn off every light on the board.',
    descTr: 'Tahtadaki tüm ışıkları söndür.',
    icon: Icons.lightbulb_rounded,
    color: const Color(0xFFFFC94D),
    builder: () => const LightsOutScreen(),
  ),
  MiniGame(
    id: 'tap_rush',
    nameEn: 'Tap Rush',
    nameTr: 'Dokun Kaç',
    descEn: 'Tap the target before it vanishes.',
    descTr: 'Hedef kaybolmadan dokun.',
    icon: Icons.touch_app_rounded,
    color: const Color(0xFFFF8A4D),
    builder: () => const TapRushScreen(),
  ),
];
