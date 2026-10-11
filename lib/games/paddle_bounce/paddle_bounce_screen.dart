import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Raketi sürükle, topu düşürme. Her sektirme puan; top hızlanır. 3 can.
class PaddleBounceScreen extends StatefulWidget {
  const PaddleBounceScreen({super.key});

  @override
  State<PaddleBounceScreen> createState() => _PaddleBounceScreenState();
}

class _PaddleBounceScreenState extends State<PaddleBounceScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'paddle_bounce';
  static const int _maxLives = 3;
  static const double _r = 9;
  static const double _padW = 96;
  static const double _padH = 14;
  static const double _padGap = 28;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  double _w = 0;
  double _h = 0;
  double _padX = -1; // raket merkezi
  double _bx = 0;
  double _by = 0;
  double _vx = 0;
  double _vy = 0;
  double _wait = 0.8;
  int _lives = _maxLives;
  int _bounces = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _bounces * 10;
  double get _speed => math.min(640.0, 300.0 + _bounces * 12.0);

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
      _lives = _maxLives;
      _bounces = 0;
      _over = false;
      _isNewBest = false;
      _serve();
    });
    _loop.start();
  }

  void _serve() {
    _wait = 0.8;
    _bx = _w > 0 ? _w / 2 : 150;
    _by = _h > 0 ? _h * 0.3 : 200;
    final a = (_rnd.nextDouble() - 0.5) * 1.0; // radyan
    _vx = _speed * math.sin(a);
    _vy = _speed * math.cos(a);
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
    final padTop = _h - _padGap - _padH;
    if (_vy > 0 && _by + _r >= padTop && _by - _r <= padTop + _padH) {
      final off = (_bx - _padX) / (_padW / 2);
      if (off.abs() <= 1.15) {
        final a = off.clamp(-1.0, 1.0).toDouble() * 1.0; // en fazla ~57°
        _bounces++;
        final s = _speed;
        _vx = s * math.sin(a);
        _vy = -s * math.cos(a);
        _by = padTop - _r;
        HapticFeedback.selectionClick();
        Sfx.correct();
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
                extra: t.p('Bounces: $_bounces', 'Sektirme: $_bounces'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Bounces $_bounces', 'Sektirme $_bounces'),
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
