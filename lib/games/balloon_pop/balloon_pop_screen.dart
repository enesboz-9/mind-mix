import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';

class _Balloon {
  _Balloon(this.x, this.y, this.speedMul, this.color);

  final double x; // 0..1 (genişlik oranı)
  double y; // 0..1 (yükseklik oranı), 1 = alt
  final double speedMul;
  final Color color;
}

/// Yükselen balonları patlat. Kaçan balon bir can götürür.
class BalloonPopScreen extends StatefulWidget {
  const BalloonPopScreen({super.key});

  @override
  State<BalloonPopScreen> createState() => _BalloonPopScreenState();
}

class _BalloonPopScreenState extends State<BalloonPopScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'balloon_pop';
  static const int _maxLives = 3;
  static const double _bw = 62;
  static const double _bh = 78;
  static const List<Color> _colors = [
    Color(0xFFFF5E7E),
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFFC94D),
    Color(0xFFA472EE),
    Color(0xFFFF9F43),
  ];

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Balloon> _balloons = [];
  double _spawn = 0;
  int _lives = _maxLives;
  int _pops = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _pops * 10;

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
      _balloons.clear();
      _spawn = 0.6;
      _lives = _maxLives;
      _pops = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _tick(double dt) {
    if (_over) return;
    final base = math.min(0.7, 0.24 + _pops * 0.005);
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.35, 1.0 - _pops * 0.012) * (0.8 + _rnd.nextDouble() * 0.4);
      _balloons.add(_Balloon(
        0.08 + _rnd.nextDouble() * 0.84,
        1.1,
        0.85 + _rnd.nextDouble() * 0.4,
        _colors[_rnd.nextInt(_colors.length)],
      ));
    }
    var escaped = 0;
    for (final b in _balloons) {
      b.y -= base * b.speedMul * dt;
    }
    _balloons.removeWhere((b) {
      if (b.y < -0.12) {
        escaped++;
        return true;
      }
      return false;
    });
    if (escaped > 0) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives -= escaped;
      if (_lives <= 0) {
        _lives = 0;
        _finish();
        return;
      }
    }
    setState(() {});
  }

  void _pop(_Balloon b) {
    if (_over) return;
    HapticFeedback.selectionClick();
    Sfx.correct();
    setState(() {
      _balloons.remove(b);
      _pops++;
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
                extra: t.p('Balloons popped: $_pops', 'Patlatılan balon: $_pops'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Pops $_pops', 'Patlatma $_pops'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final w = box.maxWidth;
                        final h = box.maxHeight;
                        return ClipRect(
                          child: Stack(
                            children: [
                              for (final b in _balloons)
                                Positioned(
                                  left: b.x * w - _bw / 2,
                                  top: b.y * h - _bh / 2,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (_) => _pop(b),
                                    child: SizedBox(
                                      width: _bw,
                                      height: _bh,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: _bw,
                                            height: _bh - 14,
                                            decoration: BoxDecoration(
                                              color: b.color,
                                              borderRadius: BorderRadius.circular(_bw),
                                            ),
                                          ),
                                          Container(
                                            width: 2,
                                            height: 14,
                                            color: Colors.white38,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
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
