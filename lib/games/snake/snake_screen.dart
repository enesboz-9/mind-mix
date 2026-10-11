import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Klasik yılan. Kaydırarak yönlendir; duvara ya da kendine çarpma.
class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key});

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'snake';
  static const int _n = 15;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  List<math.Point<int>> _snake = [];
  math.Point<int> _food = const math.Point<int>(0, 0);
  math.Point<int> _dir = const math.Point<int>(1, 0);
  math.Point<int> _nextDir = const math.Point<int>(1, 0);
  double _acc = 0;
  Offset _swipe = Offset.zero;
  int _eaten = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _eaten * 10;
  double get _interval => math.max(0.075, 0.17 - _eaten * 0.0035);

  @override
  void initState() {
    super.initState();
    _loop = GameLoop(this, _tick);
    _start();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      const c = _n ~/ 2;
      _snake = [
        const math.Point<int>(c, c),
        const math.Point<int>(c - 1, c),
        const math.Point<int>(c - 2, c),
      ];
      _dir = const math.Point<int>(1, 0);
      _nextDir = _dir;
      _acc = -0.9; // başlamadan önce kısa bir bekleme
      _eaten = 0;
      _over = false;
      _isNewBest = false;
      _placeFood();
    });
    _loop.start();
  }

  void _placeFood() {
    while (true) {
      final p = math.Point<int>(_rnd.nextInt(_n), _rnd.nextInt(_n));
      if (!_snake.contains(p)) {
        _food = p;
        return;
      }
    }
  }

  void _turn(int dx, int dy) {
    // Olduğu yerde geri dönmek yasak.
    if (dx == -_dir.x && dy == -_dir.y) return;
    _nextDir = math.Point<int>(dx, dy);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _swipe += d.delta;
    if (_swipe.distance < 14) return;
    if (_swipe.dx.abs() > _swipe.dy.abs()) {
      _turn(_swipe.dx > 0 ? 1 : -1, 0);
    } else {
      _turn(0, _swipe.dy > 0 ? 1 : -1);
    }
    _swipe = Offset.zero;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _turn(-1, 0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _turn(1, 0);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _turn(0, -1);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _turn(0, 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _tick(double dt) {
    if (_over) return;
    _acc += dt;
    var stepped = false;
    while (_acc >= _interval && !_over) {
      _acc -= _interval;
      _step();
      stepped = true;
    }
    if (stepped && !_over) setState(() {});
  }

  void _step() {
    _dir = _nextDir;
    final head = _snake.first;
    final next = math.Point<int>(head.x + _dir.x, head.y + _dir.y);
    final ate = next == _food;
    // Kuyruk bu hamlede ilerleyeceği için yemek yemediyse kuyruk hücresi serbest.
    final body = ate ? _snake : _snake.sublist(0, _snake.length - 1);
    if (next.x < 0 || next.y < 0 || next.x >= _n || next.y >= _n || body.contains(next)) {
      _finish();
      return;
    }
    _snake.insert(0, next);
    if (ate) {
      _eaten++;
      HapticFeedback.selectionClick();
      Sfx.correct();
      if (_snake.length >= _n * _n) {
        _finish();
        return;
      }
      _placeFood();
    } else {
      _snake.removeLast();
    }
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
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
                extra: t.p('Length: ${_snake.length}', 'Uzunluk: ${_snake.length}'),
                onAgain: _start,
                onMenu: _close,
              )
            : Focus(
                autofocus: true,
                onKeyEvent: _onKey,
                child: Column(
                  children: [
                    GameHud(
                      label: t.p('Length ${_snake.length}', 'Uzunluk ${_snake.length}'),
                      score: _score,
                      onClose: _close,
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (_) => _swipe = Offset.zero,
                        onPanUpdate: _onPanUpdate,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: CustomPaint(
                                painter: _SnakePainter(_snake, _food, _n),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SnakePainter extends CustomPainter {
  _SnakePainter(this.snake, this.food, this.n);

  final List<math.Point<int>> snake;
  final math.Point<int> food;
  final int n;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / n;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      Paint()..color = AppColors.surface,
    );
    for (var i = snake.length - 1; i >= 0; i--) {
      final p = snake[i];
      final isHead = i == 0;
      final paint = Paint()
        ..color = isHead ? const Color(0xFF7DFFB0) : const Color(0xFF3DDC84);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(p.x * cell + 1, p.y * cell + 1, cell - 2, cell - 2),
          Radius.circular(cell * 0.3),
        ),
        paint,
      );
    }
    canvas.drawCircle(
      Offset((food.x + 0.5) * cell, (food.y + 0.5) * cell),
      cell * 0.36,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _SnakePainter oldDelegate) => true;
}
