import 'dart:math' as math;

import 'color_utils.dart';

/// Bir tur için hedef renk + yakın "tuzak" kartlar üretir.
class Round {
  const Round({
    required this.target,
    required this.cards,
    required this.correctIndex,
  });

  final Rgb target;
  final List<Rgb> cards;
  final int correctIndex;
}

class ChoiceBuilder {
  ChoiceBuilder([math.Random? random]) : _rnd = random ?? math.Random();

  final math.Random _rnd;

  /// Rastgele, gamut kenarına çok yaslanmayan bir hedef renk.
  Rgb randomTarget() {
    final h = _rnd.nextDouble() * 360;
    final s = 0.35 + _rnd.nextDouble() * 0.5;
    final l = 0.32 + _rnd.nextDouble() * 0.38;
    return ColorUtils.hslToRgb(h, s, l);
  }

  double _gauss() {
    // Box-Muller
    final u1 = math.max(_rnd.nextDouble(), 1e-9);
    final u2 = _rnd.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// [cardCount] kartlık tur üretir. Tuzaklar hedeften yaklaşık [deltaE]
  /// uzaklıkta (LAB uzayında), birbirlerinden de ayırt edilecek kadar ayrıktır.
  /// Üretilemezse null döner (çağıran yeni hedefle tekrar dener).
  Round? build({required int cardCount, required double deltaE}) {
    final target = randomTarget();
    final lab = ColorUtils.rgbToLab(target);
    final needed = cardCount - 1;

    final picked = <Rgb>[];
    final pickedLab = <Lab>[];

    var sepFactor = 0.8; // tuzaklar arası asgari mesafe = sepFactor * deltaE
    var attempts = 0;
    var sinceRelax = 0;

    while (picked.length < needed && attempts < 1500) {
      attempts++;
      sinceRelax++;
      if (sinceRelax > 120 && sepFactor > 0.35) {
        sepFactor -= 0.1;
        sinceRelax = 0;
      }

      var dx = _gauss(), dy = _gauss(), dz = _gauss();
      final len = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (len < 1e-6) continue;
      final radius = deltaE * (0.9 + _rnd.nextDouble() * 0.2);
      dx = dx / len * radius;
      dy = dy / len * radius;
      dz = dz / len * radius;

      final cand = ColorUtils.labToRgb(Lab(lab.l + dx, lab.a + dy, lab.b + dz));
      if (cand == null) continue;

      // 8 bit yuvarlamadan sonra gerçek farkı kontrol et.
      final candLab = ColorUtils.rgbToLab(cand);
      final dTarget = ColorUtils.deltaE(candLab, lab);
      if (dTarget < math.max(1.5, deltaE * 0.6)) continue;
      if (cand == target || picked.contains(cand)) continue;

      var ok = true;
      for (final p in pickedLab) {
        if (ColorUtils.deltaE(candLab, p) < sepFactor * deltaE) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;

      picked.add(cand);
      pickedLab.add(candLab);
    }

    if (picked.length < needed) return null;

    final cards = <Rgb>[...picked];
    final correctIndex = _rnd.nextInt(cardCount);
    cards.insert(correctIndex, target);
    return Round(target: target, cards: cards, correctIndex: correctIndex);
  }

  /// Üretim başarısız olursa yeni hedefle birkaç kez dener.
  Round buildWithRetry({required int cardCount, required double deltaE}) {
    for (var i = 0; i < 40; i++) {
      final r = build(cardCount: cardCount, deltaE: deltaE);
      if (r != null) return r;
    }
    // Son çare: daha geniş fark.
    return build(cardCount: cardCount, deltaE: deltaE * 1.5) ??
        buildWithRetry(cardCount: cardCount, deltaE: deltaE * 1.5);
  }
}
