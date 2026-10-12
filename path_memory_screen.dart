import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

enum _Phase { show, input, done }

/// Işığın tahtada hangi yolu izlediğini izle, aynı yolu aynı sırayla tekrar et.
/// Yol komşu karelerden oluşur. 3 can.
class PathMemoryScreen extends StatefulWidget {
  const PathMemoryScreen({super.key});

  @override
  State<PathMemoryScreen> createState() => _PathMemoryScreenState();
}

class _PathMemoryScreenState extends State<PathMemoryScreen> {
  static const String _id = 'path_memory';

  final math.Random _rnd = math.Random();

  List<int> _path = [];
  int _n = 3;
  int _lit = -1;
  int _step = 0;
  int _wrongCell = -1;
  int _level = 1;
  int _lives = 3;
  int _score = 0;
  int _best = 0;
  int _gen = 0; // eski gösterim döngülerini iptal etmek için
  bool _over = false;
  bool _isNewBest = false;
  _Phase _phase = _Phase.show;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _gen++;
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _level = 1;
      _lives = 3;
      _score = 0;
      _over = false;
      _isNewBest = false;
    });
    _newRound();
  }

  void _newRound() {
    _n = _level <= 4 ? 3 : (_level <= 9 ? 4 : 5);
    final len = math.min(14, _level + 2);
    _path = _makePath(_n, len);
    _showPath();
  }

  List<int> _makePath(int n, int len) {
    var target = len;
    var attempts = 0;
    while (true) {
      attempts++;
      if (attempts > 300) {
        target = math.max(2, target - 1);
        attempts = 0;
      }
      final start = _rnd.nextInt(n * n);
      final path = <int>[start];
      final used = <int>{start};
      while (path.length < target) {
        final cur = path.last;
        final r = cur ~/ n;
        final c = cur % n;
        final opts = <int>[];
        for (final d in const [
          [1, 0],
          [-1, 0],
          [0, 1],
          [0, -1],
        ]) {
          final nr = r + d[0];
          final nc = c + d[1];
          if (nr < 0 || nc < 0 || nr >= n || nc >= n) continue;
          final idx = nr * n + nc;
          if (used.contains(idx)) continue;
          opts.add(idx);
        }
        if (opts.isEmpty) break;
        final next = opts[_rnd.nextInt(opts.length)];
        path.add(next);
        used.add(next);
      }
      if (path.length == target) return path;
    }
  }

  Future<void> _showPath() async {
    final gen = ++_gen;
    setState(() {
      _phase = _Phase.show;
      _lit = -1;
      _step = 0;
      _wrongCell = -1;
    });
    final stepMs = math.max(260, 520 - _level * 16);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    for (final cell in _path) {
      if (!mounted || gen != _gen) return;
      setState(() => _lit = cell);
      await Future<void>.delayed(Duration(milliseconds: stepMs));
      if (!mounted || gen != _gen) return;
      setState(() => _lit = -1);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (!mounted || gen != _gen) return;
    setState(() => _phase = _Phase.input);
  }

  Future<void> _tap(int cell) async {
    if (_phase != _Phase.input || _over) return;
    if (cell == _path[_step]) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() => _step++);
      if (_step == _path.length) {
        setState(() {
          _phase = _Phase.done;
          _score += _path.length * 10;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        _level++;
        _newRound();
      }
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _wrongCell = cell;
        _phase = _Phase.done;
      });
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      if (_lives <= 0) {
        await _finish();
      } else {
        _showPath();
      }
    }
  }

  Future<void> _finish() async {
    Sfx.over();
    setState(() => _over = true);
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Color _cellColor(int i) {
    if (i == _wrongCell) return AppColors.bad;
    if (i == _lit) return AppColors.accent;
    if (_phase != _Phase.show) {
      final idx = _path.indexOf(i);
      if (idx >= 0 && idx < _step) return AppColors.good;
    }
    return AppColors.surface;
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final String hint;
    switch (_phase) {
      case _Phase.show:
        hint = t.p('Watch the path…', 'Yolu izle…');
        break;
      case _Phase.input:
        hint = t.p('Repeat it!', 'Şimdi sen tekrar et!');
        break;
      case _Phase.done:
        hint = '';
        break;
    }
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
                    lives: _lives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
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
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTapDown: (_) => _tap(r * _n + c),
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 120),
                                              margin: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: _cellColor(r * _n + c),
                                                borderRadius: BorderRadius.circular(14),
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
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
