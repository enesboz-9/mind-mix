import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Sol üst köşeden başlayarak tüm tahtayı tek renge boya. Sınırlı hamlen var.
/// Her bölüm biraz daha büyük tahta ve daha az pay bırakır.
class ColorFloodScreen extends StatefulWidget {
  const ColorFloodScreen({super.key});

  @override
  State<ColorFloodScreen> createState() => _ColorFloodScreenState();
}

class _ColorFloodScreenState extends State<ColorFloodScreen> {
  static const String _id = 'color_flood';
  static const List<Color> _palette = [
    Color(0xFFFF5E7E),
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFFC94D),
    Color(0xFFA472EE),
    Color(0xFFFF8A4D),
  ];

  final math.Random _rnd = math.Random();

  late List<List<int>> _grid;
  int _n = 6;
  int _colors = 4;
  int _movesLeft = 0;
  int _level = 1;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _level = 1;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _busy = false;
    });
    _setupLevel();
  }

  void _setupLevel() {
    _n = math.min(12, 6 + (_level - 1) ~/ 2);
    _colors = math.min(6, 4 + (_level - 1) ~/ 3);
    setState(() {
      _grid = List.generate(
        _n,
        (_) => List.generate(_n, (_) => _rnd.nextInt(_colors)),
      );
      // Tahta büyüdükçe ve renk arttıkça hamle sayısı da artar, ama pay azalır.
      final base = (_n * _colors * 0.55).round();
      _movesLeft = math.max(6, base - (_level ~/ 2));
    });
  }

  /// Sol üst köşeyle bağlantılı hücrelerin kümesi.
  List<List<bool>> _flooded() {
    final seen = List.generate(_n, (_) => List.filled(_n, false));
    final target = _grid[0][0];
    final stack = <int>[0];
    seen[0][0] = true;
    while (stack.isNotEmpty) {
      final cur = stack.removeLast();
      final r = cur ~/ _n;
      final c = cur % _n;
      for (final d in const [
        [1, 0],
        [-1, 0],
        [0, 1],
        [0, -1],
      ]) {
        final nr = r + d[0];
        final nc = c + d[1];
        if (nr < 0 || nc < 0 || nr >= _n || nc >= _n) continue;
        if (seen[nr][nc] || _grid[nr][nc] != target) continue;
        seen[nr][nc] = true;
        stack.add(nr * _n + nc);
      }
    }
    return seen;
  }

  bool _isSolved() {
    final c = _grid[0][0];
    for (final row in _grid) {
      for (final v in row) {
        if (v != c) return false;
      }
    }
    return true;
  }

  Future<void> _pick(int color) async {
    if (_over || _busy) return;
    if (color == _grid[0][0]) return;
    HapticFeedback.selectionClick();
    final flood = _flooded();
    setState(() {
      for (var r = 0; r < _n; r++) {
        for (var c = 0; c < _n; c++) {
          if (flood[r][c]) _grid[r][c] = color;
        }
      }
      _movesLeft--;
    });
    if (_isSolved()) {
      _busy = true;
      Sfx.correct();
      final gain = 100 + _movesLeft * 10 + _level * 10;
      setState(() => _score += gain);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      _level++;
      _busy = false;
      _setupLevel();
    } else if (_movesLeft <= 0) {
      await _finish();
    }
  }

  Future<void> _finish() async {
    Sfx.wrong();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
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
                extra: t.p('Reached level $_level', '$_level. seviyeye ulaştın'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.p('Moves left: $_movesLeft', 'Kalan hamle: $_movesLeft'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _movesLeft <= 3 ? AppColors.bad : Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Column(
                            children: [
                              for (var r = 0; r < _n; r++)
                                Expanded(
                                  child: Row(
                                    children: [
                                      for (var c = 0; c < _n; c++)
                                        Expanded(
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 160),
                                            margin: const EdgeInsets.all(1),
                                            decoration: BoxDecoration(
                                              color: _palette[_grid[r][c]],
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                          ),
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _colors; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: GestureDetector(
                              onTap: () => _pick(i),
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: _palette[i],
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _grid[0][0] == i ? Colors.white : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
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
