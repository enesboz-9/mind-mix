import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'backdrop.dart';
import 'random_game.dart';
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
    final accent = GameAccent.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 2),
      child: Row(
        children: [
          _HudButton(
            icon: Icons.close_rounded,
            color: color,
            tooltip: settings.t.exit,
            onTap: onClose,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const Spacer(),
          if (timeText != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_rounded, size: 15, color: color.withAlpha(200)),
                  const SizedBox(width: 4),
                  Text(
                    timeText!,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          if (lives != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < maxLives; i++)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: i < lives!
                          ? Icon(
                              Icons.favorite_rounded,
                              key: const ValueKey<bool>(true),
                              color: AppColors.accent,
                              size: 20,
                              shadows: const [
                                Shadow(color: Color(0x88FF5E7E), blurRadius: 8),
                              ],
                            )
                          : Icon(
                              Icons.favorite_border_rounded,
                              key: const ValueKey<bool>(false),
                              color: color.withAlpha(90),
                              size: 20,
                            ),
                    ),
                ],
              ),
            ),
          _HudButton(
            icon: Icons.casino_rounded,
            color: color,
            tooltip: settings.t.randomGame,
            onTap: () => RandomGame.replaceWithRandom(context),
          ),
          const SizedBox(width: 6),
          _HudButton(
            icon: settings.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
            color: color,
            tooltip: settings.t.musicTooltip,
            onTap: () => settings.setMusic(!settings.musicOn),
          ),
          const SizedBox(width: 10),
          _ScorePill(score: score, accent: accent),
        ],
      ),
    );
  }
}

/// Cam görünümlü yuvarlak HUD düğmesi.
class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withAlpha(14),
        shape: const CircleBorder(side: BorderSide(color: Color(0x1AFFFFFF))),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }
}

/// Skor değiştikçe "zıplayan" rozet.
class _ScorePill extends StatelessWidget {
  const _ScorePill({required this.score, required this.accent});

  final int score;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(score),
      tween: Tween<double>(begin: 1.25, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(scale: v, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: [accent.withAlpha(110), accent.withAlpha(46)],
          ),
          border: Border.all(color: accent.withAlpha(130)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(
              '$score',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Yuvarlak, gradyanlı, basınca küçülen düğme.
class PillButton extends StatefulWidget {
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
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final c = widget.color;
    final hsl = HSLColor.fromColor(c);
    final light = hsl.withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0).toDouble()).toColor();
    final radius = BorderRadius.circular(widget.height / 2);

    return AnimatedScale(
      scale: _down ? 0.96 : 1,
      duration: const Duration(milliseconds: 100),
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: c.withAlpha(100),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [light, c],
                ),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onPressed,
                onHighlightChanged: (v) => setState(() => _down = v),
                child: Center(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.textColor,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ortak "oyun bitti" paneli: skor sayaç gibi sayar, yeni rekorda konfeti yağar.
class GameOverPanel extends StatefulWidget {
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
  State<GameOverPanel> createState() => _GameOverPanelState();
}

class _GameOverPanelState extends State<GameOverPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isNewBest) _confetti.forward();
  }

  @override
  void didUpdateWidget(covariant GameOverPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rekor bilgisi skor kaydedildikten sonra gelir; o an konfeti başlasın.
    if (widget.isNewBest && !oldWidget.isNewBest) _confetti.forward(from: 0);
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final accent = GameAccent.of(context);
    final record = widget.isNewBest;
    final badgeColor = record ? AppColors.gold : accent;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _ConfettiPainter(_confetti)),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Opacity(
                opacity: v.clamp(0.0, 1.0).toDouble(),
                child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [badgeColor.withAlpha(120), badgeColor.withAlpha(30)],
                      ),
                      border: Border.all(color: badgeColor.withAlpha(160), width: 2),
                      boxShadow: [
                        BoxShadow(color: badgeColor.withAlpha(90), blurRadius: 28),
                      ],
                    ),
                    child: Icon(
                      record ? Icons.emoji_events_rounded : Icons.flag_rounded,
                      size: 44,
                      color: badgeColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t.gameOver,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: widget.score),
                    duration: Duration(milliseconds: 500 + math.min(widget.score, 600)),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, accent],
                      ).createShader(rect),
                      child: Text(
                        '$v',
                        style: const TextStyle(
                          fontSize: 76,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    t.points,
                    style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                  ),
                  if (widget.extra != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(14),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(24)),
                      ),
                      child: Text(
                        widget.extra!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (record)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD86B), Color(0xFFFF9F43)],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded,
                              size: 18, color: Color(0xFF3A2600)),
                          const SizedBox(width: 6),
                          Text(
                            t.newRecord,
                            style: const TextStyle(
                              color: Color(0xFF3A2600),
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 18, color: AppColors.textDim),
                        const SizedBox(width: 6),
                        Text(
                          t.bestScore(widget.best),
                          style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                        ),
                      ],
                    ),
                  const SizedBox(height: 34),
                  PillButton(label: t.playAgain, color: accent, onPressed: widget.onAgain),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => RandomGame.replaceWithRandom(context),
                    icon: const Icon(Icons.casino_rounded),
                    label: Text(t.randomGame, style: const TextStyle(fontSize: 16)),
                  ),
                  TextButton(
                    onPressed: widget.onMenu,
                    child: Text(t.mainMenu, style: const TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece(this.x, this.delay, this.speed, this.size, this.spin, this.color);

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double spin;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t) : super(repaint: t);

  final Animation<double> t;

  static const List<Color> _palette = [
    Color(0xFFFF5E7E),
    Color(0xFFFFC94D),
    Color(0xFF3DDC84),
    Color(0xFF4D9DFF),
    Color(0xFFA472EE),
    Color(0xFFFF9F43),
  ];

  static final List<_ConfettiPiece> _pieces = () {
    final rnd = math.Random(11);
    return List<_ConfettiPiece>.generate(48, (i) {
      return _ConfettiPiece(
        rnd.nextDouble(),
        rnd.nextDouble() * 0.3,
        1.0 + rnd.nextDouble() * 0.7,
        5 + rnd.nextDouble() * 6,
        (rnd.nextDouble() - 0.5) * 14,
        _palette[rnd.nextInt(_palette.length)],
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (v <= 0 || v >= 1) return;
    final fade = 1 - math.max(0.0, (v - 0.8) / 0.2);
    final paint = Paint();
    for (final p in _pieces) {
      final local = ((v - p.delay) / (1 - p.delay)).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      final y = (-0.08 + local * p.speed) * size.height;
      final sway = math.sin(local * 6 + p.x * 9) * 18;
      final x = p.x * size.width + sway;
      paint.color = p.color.withAlpha((230 * fade).round());
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(local * p.spin);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => false;
}
