import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/audio_service.dart';
import '../core/mini_game.dart';
import '../core/score_store.dart';
import '../core/theme.dart';
import '../games/registry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, int> _best = {};

  @override
  void initState() {
    super.initState();
    _loadBest();
  }

  Future<void> _loadBest() async {
    final result = <String, int>{};
    for (final g in allGames) {
      result[g.id] = await ScoreStore.best(g.id);
    }
    if (!mounted) return;
    setState(() {
      _best
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _open(MiniGame game) async {
    // Tarayıcılar ses için kullanıcı dokunuşu ister; müziği burada başlatıyoruz.
    if (AppSettings.instance.musicOn) AudioService.instance.playMusic();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => game.builder()),
    );
    _loadBest();
  }

  /// Kart yüksekliği içeriğe ve yazı ölçeğine göre hesaplanır; böylece
  /// "BOTTOM OVERFLOWED" hatası hiçbir ekran/yazı boyutunda oluşmaz.
  double _cardHeight(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final name = scaler.scale(17) * 1.3;
    final desc = scaler.scale(12) * 1.35 * 2;
    final bottom = math.max(30.0, scaler.scale(12) * 1.3 + 14);
    // padding(32) + ikon(48) + boşluklar(12 + 4 + 10) + metinler + alt satır
    return 32 + 48 + 12 + name + 4 + desc + 10 + bottom + 2;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = settings.t;
    final cardHeight = _cardHeight(context);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF191B27), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _LangSwitch(
                            lang: settings.lang,
                            onChanged: settings.setLang,
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: t.musicTooltip,
                            onPressed: () => settings.setMusic(!settings.musicOn),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              minimumSize: const Size(44, 44),
                            ),
                            icon: Icon(
                              settings.musicOn
                                  ? Icons.music_note_rounded
                                  : Icons.music_off_rounded,
                              color: settings.musicOn
                                  ? AppColors.accent
                                  : AppColors.textDim,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (rect) => const LinearGradient(
                              colors: [Color(0xFFFFB3C1), Color(0xFFFF5E7E), Color(0xFFA472EE)],
                            ).createShader(rect),
                            child: const Text(
                              'Mind Mix',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.tagline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textDim,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 230,
                        mainAxisExtent: cardHeight,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final g = allGames[i];
                          return _Entrance(
                            index: i,
                            child: _GameCard(
                              game: g,
                              best: _best[g.id] ?? 0,
                              onTap: () => _open(g),
                            ),
                          );
                        },
                        childCount: allGames.length,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartların sırayla yukarı kayarak belirmesi.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: child),
      ),
      child: child,
    );
  }
}

class _GameCard extends StatefulWidget {
  const _GameCard({required this.game, required this.best, required this.onTap});

  final MiniGame game;
  final int best;
  final VoidCallback onTap;

  @override
  State<_GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<_GameCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final game = widget.game;
    final played = widget.best > 0;
    final radius = BorderRadius.circular(24);

    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [game.color.withAlpha(46), AppColors.surface],
              stops: const [0, 0.65],
            ),
            border: Border.all(color: game.color.withAlpha(60)),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: game.color.withAlpha(50),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(game.icon, color: game.color, size: 28),
                  ),
                  const SizedBox(height: 12),
                  // Uzun isimler ("Sequence Echo") kesilmek yerine küçülür.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      game.name(t),
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    game.desc(t),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textDim,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (played) ...[
                                Icon(Icons.emoji_events_rounded,
                                    size: 15, color: game.color),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                played ? '${widget.best}' : t.noScoreYet,
                                maxLines: 1,
                                style: TextStyle(
                                  color: played ? game.color : AppColors.textDim,
                                  fontSize: 12,
                                  height: 1.3,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: game.color.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.play_arrow_rounded,
                            size: 20, color: game.color),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// EN | TR geçiş düğmesi (kaydırmalı hap şeklinde).
class _LangSwitch extends StatelessWidget {
  const _LangSwitch({required this.lang, required this.onChanged});

  final String lang;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final code in const ['en', 'tr'])
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(code),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: lang == code ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  code.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: lang == code ? Colors.white : AppColors.textDim,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
