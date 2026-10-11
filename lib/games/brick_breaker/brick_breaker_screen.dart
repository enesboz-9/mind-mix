import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Raketi sürükle, topla tuğlaları kır. Tüm tuğlalar bitince yeni, daha dolu bir
/// duvar gelir. Top her tuğlada biraz hızlanır. 3 can.
class BrickBreakerScreen extends StatefulWidget {
  const BrickBreakerScreen({super.key});

  @override
  State<BrickBreakerScreen> createState() => _BrickBreakerScreenState();
}

class _BrickBreakerScreenState extends State<BrickBreakerScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'brick_breaker';
  static const int _maxLives = 3;
  static const int _cols = 7;
  static const double _gap = 4;
  static const double _margin = 12;
  static const double _brickH = 20;
  static const double _top = 16;
  static const double _r = 8;
  static const double _padW = 92;
  static const double _padH = 14;
  static const double _padGap = 28;
  static const List<Color> _rowColors = [
    Color(0xFFFF5E7E),
    Color(0xFFFF8A4D),
    Color(0xFFFFC94D),
    Color(0xFF3DDC84),
    Color(0xFF22D3EE),
    Color(0xFF4D9DFF),
    Color(0xFFA472EE),
  ];

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  List<bool> _bricks = [];
  double _w = 0;
  double _h = 0;
  double _padX = -1;
  double _bx = 0;
  double _by = 0;
  double _vx = 0;
  double _vy = 0;
  double _wait = 0.8;
  int _level = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _destroyed = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _rows => math.min(3 + _level, 7);
  double get _speed => math.min(620.0, 320.0 + _destroyed * 3.0 + _level * 10.0);

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
      _level = 1;
      _lives = _maxLives;
      _score = 0;
      _destroyed = 0;
      _over = false;
      _isNewBest = false;
      _buildWall();
      _serve();
    });
    _loop.start();
  }

  void _buildWall() {
    _bricks = List<bool>.filled(_rows * _cols, true);
  }

  void _serve() {
    _wait = 0.8;
    _bx = _w > 0 ? _w / 2 : 150;
    _by = _h > 0 ? _h * 0.62 : 300;
    final a = (_rnd.nextDouble() - 0.5) * 0.9;
    _vx = _speed * math.sin(a);
    _vy = _speed * math.cos(a);
  }

  Rect _brickRect(int i) {
    final bw = (_w - 2 * _margin - (_cols - 1) * _gap) / _cols;
    final x = _margin + (i % _cols) * (bw + _gap);
    final y = _top + (i ~/ _cols) * (_brickH + _gap);
    return Rect.fromLTWH(x, y, bw, _brickH);
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    if (_padX < 0) _padX = _w / 2;
    if (_wait > 0) {
      _wait -= dt;
      setState(() {});
      return;
    }
    _bx += _vx * dt;
    _by += _vy * dt;

    if (_bx < _r) {
      _bx = _r;
      _vx = _vx.abs();
    } else if (_bx > _w - _r) {
      _bx = _w - _r;
      _vx = -_vx.abs();
    }
    if (_by < _r) {
      _by = _r;
      _vy = _vy.abs();
    }

    // Tuğla çarpışması (tick başına en fazla bir tuğla).
    for (var i = 0; i < _bricks.length; i++) {
      if (!_bricks[i]) continue;
      final rect = _brickRect(i);
      final cx = _bx.clamp(rect.left, rect.right).toDouble();
      final cy = _by.clamp(rect.top, rect.bottom).toDouble();
      final dx = _bx - cx;
      final dy = _by - cy;
      if (dx * dx + dy * dy > _r * _r) continue;
      _bricks[i] = false;
      _destroyed++;
      _score += 10;
      final ox = (_bx - rect.center.dx).abs() / (rect.width / 2);
      final oy = (_by - rect.center.dy).abs() / (rect.height / 2);
      if (ox > oy) {
        _vx = _bx > rect.center.dx ? _vx.abs() : -_vx.abs();
      } else {
        _vy = _by > rect.center.dy ? _vy.abs() : -_vy.abs();
      }
      HapticFeedback.selectionClick();
      Sfx.correct();
      break;
    }

    if (!_bricks.any((b) => b)) {
      _score += 50;
      _level++;
      _buildWall();
      _serve();
      setState(() {});
      return;
    }

    final padTop = _h - _padGap - _padH;
    if (_vy > 0 && _by + _r >= padTop && _by - _r <= padTop + _padH) {
      final off = (_bx - _padX) / (_padW / 2);
      if (off.abs() <= 1.15) {
        final a = off.clamp(-1.0, 1.0).toDouble() * 1.0;
        final s = _speed;
        _vx = s * math.sin(a);
        _vy = -s * math.cos(a);
        _by = padTop - _r;
        HapticFeedback.selectionClick();
      }
    }

    if (_by - _r > _h) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives--;
      if (_lives <= 0) {
        _lives = 0;
        _finish();
        return;
      }
      _serve();
    }
    setState(() {});
  }

  void _move(double dx) {
    if (_w <= 0) return;
    _padX = dx.clamp(_padW / 2, _w - _padW / 2).toDouble();
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
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
                extra: t.p('Bricks: $_destroyed', 'Tuğla: $_destroyed'),
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
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _w = box.maxWidth;
                        _h = box.maxHeight;
                        final px = _padX < 0 ? _w / 2 : _padX;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (d) => _move(d.localPosition.dx),
                          onPanUpdate: (d) => _move(d.localPosition.dx),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                for (var i = 0; i < _bricks.length; i++)
                                  if (_bricks[i])
                                    Positioned.fromRect(
                                      rect: _brickRect(i),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _rowColors[(i ~/ _cols) % _rowColors.length],
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                      ),
                                    ),
                                Positioned(
                                  left: _bx - _r,
                                  top: _by - _r,
                                  child: Container(
                                    width: _r * 2,
                                    height: _r * 2,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: px - _padW / 2,
                                  top: _h - _padGap - _padH,
                                  child: Container(
                                    width: _padW,
                                    height: _padH,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
