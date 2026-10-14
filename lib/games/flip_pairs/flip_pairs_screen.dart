import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _flipColor = Color(0xFF22D3EE);

class _FlipCard {
  _FlipCard(this.symbol);

  final int symbol;
  bool up = false;
  bool matched = false;
}

/// Kartları çevirip çiftleri bul. Yanlış eşleşme can götürür; tahta bitince
/// bir sonraki tur daha çok kartla gelir.
class FlipPairsScreen extends StatefulWidget {
  const FlipPairsScreen({super.key});

  @override
  State<FlipPairsScreen> createState() => _FlipPairsScreenState();
}

class _FlipPairsScreenState extends State<FlipPairsScreen> {
  static const String _id = 'flip_pairs';
  static const int _maxLives = 5;
  static const List<int> _pairsPerRound = [3, 4, 6, 8];
  static const List<IconData> _icons = [
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.pets_rounded,
    Icons.cloud_rounded,
    Icons.music_note_rounded,
    Icons.local_fire_department_rounded,
    Icons.eco_rounded,
  ];
  static const List<Color> _colors = [
    Color(0xFFFF5E7E),
    Color(0xFFFFC94D),
    Color(0xFF3DDC84),
    Color(0xFFA472EE),
    Color(0xFF4D9DFF),
    Color(0xFFFF8A4D),
    Color(0xFFE879F9),
    Color(0xFF2DD4BF),
  ];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<_FlipCard> _cards = [];
  int? _first;
  bool _busy = false;
  bool _over = false;
  bool _isNewBest = false;
  int _round = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;

  int get _pairs => _pairsPerRound[math.min(_round - 1, _pairsPerRound.length - 1)];
  int get _cols => _pairs == 3 ? 3 : 4;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _deal() {
    final symbols = <int>[];
    for (var i = 0; i < _pairs; i++) {
      symbols.add(i);
      symbols.add(i);
    }
    symbols.shuffle(_rnd);
    _cards = [for (final s in symbols) _FlipCard(s)];
    _first = null;
    _busy = false;
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _round = 1;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _deal();
    });
  }

  void _tap(int i) {
    if (_busy || _over) return;
    final c = _cards[i];
    if (c.up || c.matched) return;
    HapticFeedback.selectionClick();
    setState(() => c.up = true);

    final firstIndex = _first;
    if (firstIndex == null) {
      _first = i;
      return;
    }
    final a = _cards[firstIndex];
    _first = null;

    if (a.symbol == c.symbol) {
      Sfx.correct();
      setState(() {
        a.matched = true;
        c.matched = true;
        _score += 10;
      });
      if (_cards.every((x) => x.matched)) {
        _busy = true;
        _timer = Timer(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          setState(() {
            _score += 20;
            _round++;
            _deal();
          });
        });
      }
    } else {
      Sfx.wrong();
      _busy = true;
      setState(() => _lives--);
      _timer = Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          a.up = false;
          c.up = false;
          _busy = false;
        });
        if (_lives <= 0) _finish();
      });
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _buildCard(int i) {
    final c = _cards[i];
    final show = c.up || c.matched;
    final color = _colors[c.symbol];
    final front = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withAlpha(c.matched ? 60 : 110), color.withAlpha(c.matched ? 24 : 44)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: color.withAlpha(c.matched ? 30 : 80), blurRadius: 14),
        ],
      ),
      child: Center(
        child: Icon(
          _icons[c.symbol],
          color: Color.lerp(color, Colors.white, 0.35),
          size: 34,
        ),
      ),
    );
    final back = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surfaceHi, AppColors.surface],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _flipColor.withAlpha(90), width: 2),
      ),
      child: Center(
        child: Icon(
          Icons.help_outline_rounded,
          color: _flipColor.withAlpha(150),
          size: 28,
        ),
      ),
    );
    return GestureDetector(
      onTap: () => _tap(i),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: show ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        builder: (context, v, _) {
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(v * math.pi),
            child: v >= 0.5
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: front,
                  )
                : back,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Boards cleared: ${_round - 1}', 'Biten tur: ${_round - 1}'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Round $_round', 'Tur $_round'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: GridView.count(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: _cols,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [for (var i = 0; i < _cards.length; i++) _buildCard(i)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
