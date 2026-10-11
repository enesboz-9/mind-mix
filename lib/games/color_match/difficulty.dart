import 'dart:math' as math;

/// Seviyeye göre kart sayısı ve renkler arası fark (ΔE).
///
/// Kural: her seviye geçişinde sırayla biri artar:
///  - tek adımlarda kart sayısı +1 (en fazla [maxCards])
///  - çift adımlarda (ya da kart sayısı 9'a ulaştıktan sonra her adımda)
///    renkler birbirine yaklaşır (ΔE küçülür, en az [minDeltaE]).
class Difficulty {
  const Difficulty({required this.cardCount, required this.deltaE});

  final int cardCount;
  final double deltaE;

  static const int startCards = 4;
  static const int maxCards = 9;
  static const double startDeltaE = 30;
  static const double minDeltaE = 3;
  static const double shrinkFactor = 0.87;

  static Difficulty forLevel(int level) {
    var cards = startCards;
    var de = startDeltaE;
    for (var step = 1; step < level; step++) {
      if (step.isOdd && cards < maxCards) {
        cards++;
      } else {
        de = math.max(minDeltaE, de * shrinkFactor);
      }
    }
    return Difficulty(cardCount: cards, deltaE: de);
  }
}
