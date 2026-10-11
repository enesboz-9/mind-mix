/// Basit EN / TR metin tablosu. Varsayılan dil İngilizcedir.
/// Oyunlara özel metinler için [p] kullanılır: `t.p('Level', 'Seviye')`.
class AppStrings {
  const AppStrings(this.isTr);

  final bool isTr;

  String p(String en, String tr) => isTr ? tr : en;

  String get appName => 'Surprise Games';
  String get tagline => p(
        'Quick brain games.\nPick one — or let fate pick for you.',
        'Hızlı zeka oyunları.\nBirini seç — ya da şansa bırak.',
      );
  String get surpriseMe => p('Surprise me!', 'Sürpriz yap!');
  String get randomGame => p('Random game', 'Rastgele oyun');
  String gamesCount(int n) => p('$n games', '$n oyun');
  String get musicTooltip => p('Music', 'Müzik');
  String get exit => p('Exit', 'Çık');
  String get best => p('Best', 'En iyi');
  String get noScoreYet => p('Not played yet', 'Henüz oynanmadı');
  String get gameOver => p('Game over', 'Oyun bitti');
  String get points => p('points', 'puan');
  String get newRecord => p('New record!', 'Yeni rekor!');
  String bestScore(int n) => p('Best score: $n', 'En yüksek skor: $n');
  String get playAgain => p('Play again', 'Tekrar oyna');
  String get mainMenu => p('Main menu', 'Ana menü');
  String level(int n) => p('Level $n', 'Seviye $n');
}
