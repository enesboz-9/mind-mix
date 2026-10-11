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

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = settings.t;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LangButton(
                    label: 'EN',
                    selected: settings.lang == 'en',
                    onTap: () => settings.setLang('en'),
                  ),
                  _LangButton(
                    label: 'TR',
                    selected: settings.lang == 'tr',
                    onTap: () => settings.setLang('tr'),
                  ),
                  IconButton(
                    tooltip: t.musicTooltip,
                    onPressed: () => settings.setMusic(!settings.musicOn),
                    icon: Icon(
                      settings.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t.appName,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              t.tagline,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDim, fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.92,
                children: [
                  for (final g in allGames)
                    _GameCard(
                      game: g,
                      best: _best[g.id] ?? 0,
                      onTap: () => _open(g),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.best, required this.onTap});

  final MiniGame game;
  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: game.color.withAlpha(40),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(game.icon, color: game.color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                game.name(t),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                game.desc(t),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textDim, fontSize: 12, height: 1.3),
              ),
              const Spacer(),
              Text(
                best > 0 ? '${t.best}: $best' : t.noScoreYet,
                style: TextStyle(
                  color: best > 0 ? game.color : AppColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.accent : AppColors.textDim,
        ),
      ),
    );
  }
}
