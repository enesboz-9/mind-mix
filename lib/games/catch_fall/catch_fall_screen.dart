import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Item {
  _Item(this.x, this.emoji, this.bomb) : y = -0.05;

  final double x; // 0..1
  double y; // 0..1
  final String emoji;
  final bool bomb;
}

/// Sepeti sürükle, meyveleri yakala, bombalardan kaç.
/// Kaçırılan meyve ya da yakalanan bomba bir can götürür.
class CatchFallScreen extends StatefulWidget {
  const CatchFallScreen({super.key});

  @override
  State<CatchFallScreen> createState() => _CatchFallScreenState();
}

class _CatchFallScreenState extends State<CatchFallScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'catch_fall';
  static const int _maxLives = 3;
  static const double _basketW = 96;
  static const double _basketH = 36;
  static const double _bottomGap = 16;
  static const List<String> _fruits = ['🍎', '🍊', '🍋', '🍇', '🍓', '🍐'];

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Item> _items = [];
  double _basketX = 0.5;
  double _spawn = 0;
  double _w = 0;
  double _h = 0;
  int _lives = _maxLives;
  int _caught = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _caught * 10;

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
      _items.clear();
      _basketX = 0.5;
      _spawn = 0.4;
      _lives = _maxLives;
      _caught = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _loseLife() {
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    _lives--;
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    final speed = math.min(0.9, 0.34 + _caught * 0.0125);
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.45, 1.0 - _caught * 0.012);
      final bomb = _caught >= 3 && _rnd.nextDouble() < 0.26;
      _items.add(_Item(
        0.08 + _rnd.nextDouble() * 0.84,
        bomb ? '💣' : _fruits[_rnd.nextInt(_fruits.length)],
        bomb,
      ));
    }
    final basketTop = _h - _bottomGap - _basketH;
    final basketLeft = _basketX * _w - _basketW / 2;
    final basketRight = basketLeft + _basketW;
    final done = <_Item>[];
    for (final it in _items) {
      it.y += speed * dt;
      final py = it.y * _h;
      final px = it.x * _w;
      if (py >= basketTop && py <= basketTop + _basketH) {
        if (px >= basketLeft - 8 && px <= basketRight + 8) {
          done.add(it);
          if (it.bomb) {
            _loseLife();
          } else {
            HapticFeedback.selectionClick();
            Sfx.correct();
            _caught++;
          }
          continue;
        }
      }
      if (py > _h + 20) {
        done.add(it);
        if (!it.bomb) _loseLife();
      }
    }
    _items.removeWhere(done.contains);
    if (_lives <= 0) {
      _lives = 0;
      _finish();
      return;
    }
    setState(() {});
  }

  void _moveTo(double dx) {
    if (_w <= 0) return;
    setState(() {
      _basketX = (dx / _w).clamp(_basketW / 2 / _w, 1 - _basketW / 2 / _w).toDouble();
    });
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
                extra: t.p('Caught: $_caught', 'Yakalanan: $_caught'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Caught $_caught', 'Yakalanan $_caught'),
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
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (d) => _moveTo(d.localPosition.dx),
                          onPanUpdate: (d) => _moveTo(d.localPosition.dx),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                for (final it in _items)
                                  Positioned(
                                    left: it.x * _w - 18,
                                    top: it.y * _h - 18,
                                    child: Text(it.emoji, style: const TextStyle(fontSize: 32)),
                                  ),
                                Positioned(
                                  left: _basketX * _w - _basketW / 2,
                                  top: _h - _bottomGap - _basketH,
                                  child: Container(
                                    width: _basketW,
                                    height: _basketH,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(22),
                                        bottomRight: Radius.circular(22),
                                        topLeft: Radius.circular(6),
                                        topRight: Radius.circular(6),
                                      ),
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
