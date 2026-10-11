import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'theme.dart';

/// Tüm oyunların üst barı: kapat, başlık, (süre), canlar, müzik ve skor.
class GameHud extends StatelessWidget {
  const GameHud({
    super.key,
    required this.label,
    required this.score,
    required this.onClose,
    this.lives,
    this.maxLives = 3,
    this.color = Colors.white,
    this.timeText,
  });

  final String label;
  final int score;
  final VoidCallback onClose;
  final int? lives;
  final int maxLives;
  final Color color;
  final String? timeText;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: color),
            tooltip: settings.t.exit,
          ),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          const Spacer(),
          if (timeText != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                timeText!,
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          if (lives != null)
            for (var i = 0; i < maxLives; i++)
              Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  i < lives! ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: color,
                  size: 22,
                ),
              ),
          IconButton(
            onPressed: () => settings.setMusic(!settings.musicOn),
            icon: Icon(
              settings.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
              color: color,
              size: 22,
            ),
          ),
          Text(
            '$score',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

/// Yuvarlak, dolu düğme.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.textColor = Colors.white,
    this.width = 240,
    this.height = 56,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color textColor;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(height / 2)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Ortak "oyun bitti" paneli.
class GameOverPanel extends StatelessWidget {
  const GameOverPanel({
    super.key,
    required this.score,
    required this.best,
    required this.isNewBest,
    required this.onAgain,
    required this.onMenu,
    this.extra,
  });

  final int score;
  final int best;
  final bool isNewBest;
  final VoidCallback onAgain;
  final VoidCallback onMenu;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.gameOver, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            Text(
              '$score',
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: AppColors.accent,
              ),
            ),
            Text(t.points, style: const TextStyle(color: AppColors.textDim, fontSize: 16)),
            if (extra != null) ...[
              const SizedBox(height: 16),
              Text(extra!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 8),
            if (isNewBest)
              Text(
                t.newRecord,
                style: const TextStyle(
                  color: AppColors.good,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Text(
                t.bestScore(best),
                style: const TextStyle(color: AppColors.textDim, fontSize: 16),
              ),
            const SizedBox(height: 40),
            PillButton(label: t.playAgain, onPressed: onAgain),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onMenu,
              child: Text(t.mainMenu, style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
