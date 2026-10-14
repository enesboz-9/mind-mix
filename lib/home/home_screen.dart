import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_settings.dart';
import '../core/audio_service.dart';
import '../core/backdrop.dart';
import '../core/categories.dart';
import '../core/game_prefs.dart';
import '../core/l10n.dart';
import '../core/mini_game.dart';
import '../core/random_game.dart';
import '../core/score_store.dart';
import '../core/theme.dart';
import '../games/registry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const int _filterAll = -1;
  static const int _filterFav = -2;

  final Map<String, int> _best = {};
  final Map<String, MiniGame> _byId = {for (final g in allGames) g.id: g};
  final TextEditingController _search = TextEditingController();
  final GamePrefs _prefs = GamePrefs.instance;
  bool _loaded = false;
  int _filter = _filterAll;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefs);
    _loadBest();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    _search.dispose();
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
  }

  Future<void> _loadBest() async {
    final result = <String, int>{};
    for (final g in allGames) {
      result[g.id] = await ScoreStore.best(g.id);
    }
    if (!mounted) return;
    setState(() {
      _loaded = true;
      _best
        ..clear()
        ..addAll(result);
    });
  }

  void _openRandom() {
    final game = RandomGame.pick();
    if (game != null) _open(game);
  }

  Future<void> _open(MiniGame game) async {
    RandomGame.lastId = game.id;
    _prefs.markPlayed(game.id);
    // Tarayıcılar ses için kullanıcı dokunuşu ister; müziği burada başlatıyoruz.
    if (AppSettings.instance.musicOn) AudioService.instance.playMusic();
    await Navigator.of(context).push(gameRoute(game));
    _loadBest();
  }

  /// Her gün değişen, herkes için aynı "günün oyunu".
  MiniGame get _daily {
    final now = DateTime.now();
    final key = now.year * 10000 + now.month * 100 + now.day;
    return allGames[(key * 31 + 7) % allGames.length];
  }

  bool _isPlayed(MiniGame g) => (_best[g.id] ?? 0) > 0 || _prefs.played.contains(g.id);

  List<MiniGame> _visible() {
    final q = _query.trim().toLowerCase();
    return allGames.where((g) {
      if (_filter == _filterFav && !_prefs.isFavorite(g.id)) return false;
      if (_filter >= 0 && categoryOf(g.id) != GameCategory.values[_filter]) return false;
      if (q.isEmpty) return true;
      return g.nameEn.toLowerCase().contains(q) ||
          g.nameTr.toLowerCase().contains(q) ||
          g.descEn.toLowerCase().contains(q) ||
          g.descTr.toLowerCase().contains(q);
    }).toList();
  }

  String _sectionTitle(AppStrings t) {
    if (_filter == _filterFav) return t.favorites;
    if (_filter >= 0) return GameCategory.values[_filter].label(t);
    return t.allGames;
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

  Widget _topBar(AppSettings settings, AppStrings t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: AppColors.accent.withAlpha(70), blurRadius: 16),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/logo/logo.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox(width: 44, height: 44),
              ),
            ),
          ),
          const Spacer(),
          _LangSwitch(lang: settings.lang, onChanged: settings.setLang),
          const SizedBox(width: 8),
          IconButton(
            tooltip: t.musicTooltip,
            onPressed: () => settings.setMusic(!settings.musicOn),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withAlpha(14),
              minimumSize: const Size(44, 44),
            ),
            icon: Icon(
              settings.musicOn ? Icons.music_note_rounded : Icons.music_off_rounded,
              color: settings.musicOn ? AppColors.accent : AppColors.textDim,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(AppStrings t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              colors: [Color(0xFFFFB3C1), Color(0xFFFF5E7E), Color(0xFFA472EE)],
            ).createShader(rect),
            child: const Text(
              'Surprise Games',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
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
            style: const TextStyle(color: AppColors.textDim, fontSize: 15, height: 1.4),
          ),
          const SizedBox(height: 20),
          _SurpriseButton(
            label: t.surpriseMe,
            hint: t.gamesCount(allGames.length),
            onTap: _openRandom,
          ),
        ],
      ),
    );
  }

  Widget _searchField(AppStrings t) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: t.searchHint,
          hintStyle: const TextStyle(color: AppColors.textDim),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textDim),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textDim),
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
          filled: true,
          fillColor: Colors.white.withAlpha(14),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: border,
          enabledBorder: border,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppColors.accent.withAlpha(140)),
          ),
        ),
      ),
    );
  }

  Widget _chips(AppStrings t) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: t.filterAll,
            icon: Icons.apps_rounded,
            color: AppColors.accent,
            selected: _filter == _filterAll,
            onTap: () => setState(() => _filter = _filterAll),
          ),
          _FilterChip(
            label: t.favorites,
            icon: Icons.favorite_rounded,
            color: AppColors.accent,
            selected: _filter == _filterFav,
            onTap: () => setState(() => _filter = _filterFav),
          ),
          for (final c in GameCategory.values)
            _FilterChip(
              label: c.label(t),
              icon: c.icon,
              color: c.color,
              selected: _filter == c.index,
              onTap: () => setState(() => _filter = c.index),
            ),
        ],
      ),
    );
  }

  Widget _recents(AppStrings t, List<MiniGame> recents) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Text(
              t.recentlyPlayed,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: recents.length,
              separatorBuilder: (context, i) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _RecentChip(
                game: recents[i],
                name: recents[i].name(t),
                onTap: () => _open(recents[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(AppStrings t) {
    final favEmpty = _filter == _filterFav && _query.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(
        children: [
          Icon(
            favEmpty ? Icons.favorite_border_rounded : Icons.search_off_rounded,
            size: 48,
            color: AppColors.textDim,
          ),
          const SizedBox(height: 12),
          Text(
            favEmpty ? t.noFavorites : t.noResults,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDim, fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsScope.of(context);
    final t = settings.t;
    final cardHeight = _cardHeight(context);

    final games = _visible();
    final browsing = _filter == _filterAll && _query.trim().isEmpty;
    final recents = <MiniGame>[
      for (final id in _prefs.recents)
        if (_byId[id] != null) _byId[id]!,
    ];
    final played = allGames.where(_isPlayed).length;
    final daily = _daily;

    return Scaffold(
      body: AmbientBackground(
        color: AppColors.accent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(child: _topBar(settings, t)),
                  SliverToBoxAdapter(child: _hero(t)),
                  if (browsing)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                        child: _DailyCard(
                          game: daily,
                          label: t.dailyGame,
                          name: daily.name(t),
                          desc: daily.desc(t),
                          onTap: () => _open(daily),
                        ),
                      ),
                    ),
                  if (browsing && recents.isNotEmpty)
                    SliverToBoxAdapter(child: _recents(t, recents)),
                  SliverToBoxAdapter(child: _searchField(t)),
                  SliverToBoxAdapter(child: _chips(t)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                _sectionTitle(t),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _filter == _filterAll && _query.trim().isEmpty
                                    ? t.playedOf(played, allGames.length)
                                    : t.gamesCount(games.length),
                                style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          if (browsing) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(
                                  begin: 0,
                                  end: allGames.isEmpty ? 0 : played / allGames.length,
                                ),
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (context, v, _) => LinearProgressIndicator(
                                  value: v,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withAlpha(16),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.accent,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (games.isEmpty)
                    SliverToBoxAdapter(child: _emptyState(t))
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisExtent: cardHeight,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final g = games[i];
                            return _Entrance(
                              key: ValueKey<String>(g.id),
                              index: i,
                              child: _GameCard(
                                game: g,
                                best: _best[g.id] ?? 0,
                                onTap: () => _open(g),
                                isFav: _prefs.isFavorite(g.id),
                                isNew: _loaded && !_isPlayed(g),
                                onFav: () => _prefs.toggleFavorite(g.id),
                              ),
                            );
                          },
                          childCount: games.length,
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

/// Günün oyunu: büyük, öne çıkan kart.
class _DailyCard extends StatelessWidget {
  const _DailyCard({
    required this.game,
    required this.label,
    required this.name,
    required this.desc,
    required this.onTap,
  });

  final MiniGame game;
  final String label;
  final String name;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(26);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.color.withAlpha(120),
              game.color.withAlpha(40),
              AppColors.surface,
            ],
            stops: const [0, 0.55, 1],
          ),
          border: Border.all(color: game.color.withAlpha(140)),
          boxShadow: [
            BoxShadow(
              color: game.color.withAlpha(50),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -26,
                  child: Icon(game.icon, size: 150, color: game.color.withAlpha(30)),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [game.color.withAlpha(150), game.color.withAlpha(60)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: game.color.withAlpha(80), blurRadius: 16),
                          ],
                        ),
                        child: Icon(
                          game.icon,
                          size: 36,
                          color: Color.lerp(game.color, Colors.white, 0.45),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.wb_sunny_rounded,
                                    size: 14, color: AppColors.gold),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(game.color, Colors.white, 0.25)!,
                              game.color,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(color: game.color.withAlpha(110), blurRadius: 14),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 28, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Son oynananlar" şeridindeki küçük kart.
class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.game, required this.name, required this.onTap});

  final MiniGame game;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [game.color.withAlpha(56), AppColors.surface],
          ),
          border: Border.all(color: game.color.withAlpha(80)),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: game.color.withAlpha(70),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    game.icon,
                    size: 22,
                    color: Color.lerp(game.color, Colors.white, 0.4),
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kategori / favori filtre hapı.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: selected ? color.withAlpha(70) : Colors.white.withAlpha(12),
            border: Border.all(
              color: selected ? color : Colors.white.withAlpha(22),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: selected ? color : AppColors.textDim),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rastgele oyun açan büyük "sürpriz" düğmesi: nabız gibi parlar, zar sallanır.
class _SurpriseButton extends StatefulWidget {
  const _SurpriseButton({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  State<_SurpriseButton> createState() => _SurpriseButtonState();
}

class _SurpriseButtonState extends State<_SurpriseButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(30);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withAlpha((70 + 70 * v).round()),
                blurRadius: 16 + 14 * v,
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
                gradient: AppColors.brand,
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: widget.onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.rotate(
                        angle: (v - 0.5) * 0.5,
                        child: const Icon(Icons.casino_rounded, color: Colors.white, size: 27),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.hint,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Kartların sırayla yukarı kayarak belirmesi.
class _Entrance extends StatelessWidget {
  const _Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + math.min(index, 8) * 70),
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
  const _GameCard({
    required this.game,
    required this.best,
    required this.onTap,
    required this.isFav,
    required this.isNew,
    required this.onFav,
  });

  final MiniGame game;
  final int best;
  final VoidCallback onTap;
  final bool isFav;
  final bool isNew;
  final VoidCallback onFav;

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
      child: Stack(
        fit: StackFit.expand,
        children: [
      Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [game.color.withAlpha(58), AppColors.surface],
              stops: const [0, 0.7],
            ),
            border: Border.all(color: game.color.withAlpha(played ? 120 : 64)),
            boxShadow: [
              BoxShadow(
                color: game.color.withAlpha(played ? 34 : 14),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
              fit: StackFit.expand,
              children: [
              Positioned(
                right: -18,
                bottom: -20,
                child: Icon(game.icon, size: 108, color: game.color.withAlpha(26)),
              ),
              Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [game.color.withAlpha(120), game.color.withAlpha(44)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: game.color.withAlpha(60), blurRadius: 14),
                      ],
                    ),
                    child: Icon(
                      game.icon,
                      color: Color.lerp(game.color, Colors.white, 0.4),
                      size: 28,
                    ),
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
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color.lerp(game.color, Colors.white, 0.25)!,
                              game.color,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: game.color.withAlpha(90), blurRadius: 10),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ],
            ),
            ),
          ),
        ),
      ),
      if (widget.isNew)
        Positioned(
          top: 17,
          right: 44,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD86B), Color(0xFFFF9F43)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                t.newBadge,
                style: const TextStyle(
                  color: Color(0xFF3A2600),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      Positioned(
        top: 8,
        right: 6,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onFav,
          child: SizedBox(
            width: 36,
            height: 36,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                widget.isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey<bool>(widget.isFav),
                size: 20,
                color: widget.isFav ? AppColors.accent : AppColors.textDim,
              ),
            ),
          ),
        ),
      ),
        ],
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
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(20)),
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
