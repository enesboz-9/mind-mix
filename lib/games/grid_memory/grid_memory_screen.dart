import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _gridColor = Color(0xFF6EE7B7);

enum _Phase { show, input, reveal }

/// Yanan kareleri aklında tut, sonra hepsini bul. Her turda bir kare artar. 3 can.
class GridMemoryScreen extends StatefulWidget {
  const GridMemoryScreen({super.key});

  @override
  State<GridMemoryScreen> createState() => _GridMemoryScreenState();
}

class _GridMemoryScreenState extends State<GridMemoryScreen> {
  static const String _id = 'grid_memory';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  Set<int> _targets = <int>{};
  Set<int> _found = <int>{};
  _Phase _phase = _Phase.show;
  int _wrongIdx = -1;
  int _level = 1;
  int _score = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _tiles => math.min(_level + 2, 14);
  int get _size => _tiles <= 5 ? 3 : (_tiles <= 9 ? 4 : 5);

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _newRound() {
    _timer?.cancel();
    final total = _size * _size;
    final order = List<int>.generate(total, (i) => i)..shuffle(_rnd);
    setState(() {
      _targets = order.take(_tiles).toSet();
      _found = <int>{};
      _wrongIdx = -1;
      _phase = _Phase.show;
    });
    _timer = Timer(Duration(milliseconds: 1000 + _tiles * 150), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.input);
    });
  }

  void _start() {
    _timer?.cancel();
    _level = 1;
    _score = 0;
    _lives = _maxLives;
    _over = false;
    _isNewBest = false;
    _newRound();
  }

  void _tap(int i) {
    if (_phase != _Phase.input || _over || _found.contains(i)) return;
    if (_targets.contains(i)) {
      HapticFeedback.selectionClick();
      setState(() => _found.add(i));
      if (_found.length == _targets.length) {
        Sfx.correct();
        _score += _tiles * 10;
        _level++;
        _timer = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _newRound();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _wrongIdx = i;
        _phase = _Phase.reveal;
      });
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        if (_lives <= 0) {
          _finish();
        } else {
          _newRound();
        }
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

  Widget _cell(int i) {
    Color fill = AppColors.surface;
    Color border = Colors.transparent;
    if (_phase == _Phase.show && _targets.contains(i)) {
      fill = _gridColor;
    } else if (_phase == _Phase.input && _found.contains(i)) {
      fill = AppColors.good.withAlpha(160);
      border = AppColors.good;
    } else if (_phase == _Phase.reveal) {
      if (i == _wrongIdx) {
        fill = AppColors.bad.withAlpha(180);
        border = AppColors.bad;
      } else if (_targets.contains(i)) {
        fill = _gridColor.withAlpha(150);
      }
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final String hint;
    if (_phase == _Phase.show) {
      hint = t.p('Remember the lit squares', 'Yanan kareleri aklında tut');
    } else if (_phase == _Phase.input) {
      hint = t.p('Tap them: ${_found.length}/${_targets.length}', 'Dokun: ${_found.length}/${_targets.length}');
    } else {
      hint = t.p('Missed one…', 'Yanlış kare…');
    }
    final n = _size;
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Most squares: ${_tiles}', 'En çok kare: $_tiles'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      hint,
                      style: const TextStyle(color: AppColors.textDim, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(math.min(box.maxWidth, box.maxHeight), 340.0);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Column(
                                children: [
                                  for (var r = 0; r < n; r++)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (var c = 0; c < n; c++)
                                            Expanded(child: _cell(r * n + c)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
