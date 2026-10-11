import 'dart:math' as math;

import 'package:mind_mix/games/color_match/choice_builder.dart';
import 'package:mind_mix/games/color_match/color_utils.dart';
import 'package:mind_mix/games/color_match/difficulty.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Difficulty', () {
    test('1. seviye 4 kart ile başlar', () {
      final d = Difficulty.forLevel(1);
      expect(d.cardCount, 4);
      expect(d.deltaE, Difficulty.startDeltaE);
    });

    test('kart sayısı 9 ile sınırlı, ΔE alt sınırın altına inmez', () {
      final d = Difficulty.forLevel(200);
      expect(d.cardCount, 9);
      expect(d.deltaE, Difficulty.minDeltaE);
    });

    test('seviye ilerledikçe zorluk azalmaz', () {
      var prev = Difficulty.forLevel(1);
      for (var l = 2; l <= 60; l++) {
        final cur = Difficulty.forLevel(l);
        expect(cur.cardCount >= prev.cardCount, isTrue);
        expect(cur.deltaE <= prev.deltaE, isTrue);
        prev = cur;
      }
    });
  });

  group('ChoiceBuilder', () {
    test('doğru kart hedefle aynı, tuzaklar hedeften farklı', () {
      final builder = ChoiceBuilder(math.Random(42));
      for (var level = 1; level <= 40; level++) {
        final diff = Difficulty.forLevel(level);
        final round = builder.buildWithRetry(
          cardCount: diff.cardCount,
          deltaE: diff.deltaE,
        );
        expect(round.cards.length, diff.cardCount);
        expect(round.cards[round.correctIndex], round.target);
        expect(round.cards.toSet().length, diff.cardCount);
        for (var i = 0; i < round.cards.length; i++) {
          if (i == round.correctIndex) continue;
          expect(
            ColorUtils.deltaERgb(round.cards[i], round.target) >= 1.5,
            isTrue,
          );
        }
      }
    });
  });

  test('RGB -> LAB -> RGB gidiş dönüş', () {
    const c = Rgb(200, 80, 120);
    final back = ColorUtils.labToRgb(ColorUtils.rgbToLab(c));
    expect(back, isNotNull);
    expect((back!.r - c.r).abs() <= 1, isTrue);
    expect((back.g - c.g).abs() <= 1, isTrue);
    expect((back.b - c.b).abs() <= 1, isTrue);
  });
}
