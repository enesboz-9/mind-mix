import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mini_game.dart';

/// "Sürpriz oyun" mantığı: listeden rastgele bir oyun seçer ve açar.
/// [pool] uygulama açılırken `allGames` ile doldurulur (bkz. main.dart).
class RandomGame {
  RandomGame._();

  static List<MiniGame> pool = const [];

  /// En son açılan oyunun kimliği; sürpriz düğmesi aynı oyunu art arda seçmesin diye.
  static String? lastId;

  static final math.Random _rnd = math.Random();

  /// Rastgele bir oyun seçer (mümkünse son oynananı hariç tutar).
  static MiniGame? pick() {
    if (pool.isEmpty) return null;
    final options = pool.length > 1
        ? pool.where((g) => g.id != lastId).toList()
        : List<MiniGame>.of(pool);
    final game = options[_rnd.nextInt(options.length)];
    lastId = game.id;
    return game;
  }

  /// Açık olan oyunu kapatmadan, yerine rastgele bir oyun koyar.
  /// Geri tuşu yine ana menüye döner.
  static void replaceWithRandom(BuildContext context) {
    final game = pick();
    if (game == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => game.builder()),
    );
  }
}
