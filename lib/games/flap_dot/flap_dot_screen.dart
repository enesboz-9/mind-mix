import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Pipe {
  _Pipe(this.x, this.gapCenter);

  double x; // piksel, sol kenar
  final double gapCenter; // piksel
  bool passed = false;
}

/// Dokununca zıpla, borular arasından geç. Bir kere çarparsan oyun biter.
class FlapDotScreen extends StatefulWidget {
  const FlapDotScreen({super.key});

  @override
  State<FlapDotScreen> createState() => _FlapDotScreenState();
}

class _FlapDotScreenState extends State<FlapDotScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'flap_dot';
  static const double _r = 14;
  static const double _pipeW = 62;
  static const double _gravity = 1500;
  static const double _flap = -470;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Pipe> _pipes = [];
  double _w = 0;
  double _h = 0;
  double _y = 0;
  double _vy = 0;
  double _t = 0;
  int _passed = 0;
  int _best = 0;
  bool _started = false;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _passed * 10;
  double get _bx => math.min(120.0, _w * 0.3);
  double get _gap => math.max(150.0, _h * 0.27);

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
      _pipes.clear();
      _y = _h > 0 ? _h / 2 : 300;
      _vy = 0;
      _t = 0;
      _passed = 0;
      _started = false;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _tap() {
    if (_over) return;
    if (!_started) {
      setState(() => _started = true);
    }
    _vy = _flap;
    HapticFeedback.selectionClick();
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    _t += dt;
    if (!_started) {
      // Başlamadan önce top hafifçe sallanır.
      _y = _h / 2 + math.sin(_t * 4) * 10;
      setState(() {});
      return;
    }
    _vy += _gravity * dt;
    _y += _vy * dt;

    final speed = math.min(270.0, 150.0 + _passed * 3.0);
    for (final p in _pipes) {
      p.x -= speed * dt;
    }
    _pipes.removeWhere((p) => p.x < -_pipeW - 4);
    if (_pipes.isEmpty || _pipes.last.x < _w - 240) {
      final margin = _gap / 2 + 50;
      final c = margin + _rnd.nextDouble() * math.max(1.0, _h - 2 * margin);
      _pipes.add(_Pipe(_w + 10, c));
    }

    final bx = _bx;
    var hit = _y - _r < 0 || _y + _r > _h;
    for (final p in _pipes) {
      if (!p.passed && p.x + _pipeW < bx - _r) {
        p.passed = true;
        _passed++;
        Sfx.correct();
      }
      if (bx + _r > p.x && bx - _r < p.x + _pipeW) {
        if (_y - _r < p.gapCenter - _gap / 2 || _y + _r > p.gapCenter + _gap / 2) {
          hit = true;
        }
      }
    }
    if (hit) {
      _finish();
      return;
    }
    setState(() {});
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
                extra: t.p('Gates passed: $_passed', 'Geçilen kapı: $_passed'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Gates $_passed', 'Kapı $_passed'),
                    score: _score,
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _w = box.maxWidth;
                        _h = box.maxHeight;
                        if (_y == 0) _y = _h / 2;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _tap(),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                for (final p in _pipes) ...[
                                  Positioned(
                                    left: p.x,
                                    top: 0,
                                    child: _pipe(p.gapCenter - _gap / 2),
                                  ),
                                  Positioned(
                                    left: p.x,
                                    top: p.gapCenter + _gap / 2,
                                    child: _pipe(_h - (p.gapCenter + _gap / 2)),
                                  ),
                                ],
                                Positioned(
                                  left: _bx - _r,
                                  top: _y - _r,
                                  child: Container(
                                    width: _r * 2,
                                    height: _r * 2,
                                    decoration: const BoxDecoration(
                                      color: AppColors.accent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                if (!_started)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: _h * 0.2,
                                    child: Text(
                                      t.p('Tap to flap', 'Zıplamak için dokun'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white70,
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

  Widget _pipe(double height) {
    return Container(
      width: _pipeW,
      height: math.max(0.0, height),
      decoration: BoxDecoration(
        color: const Color(0xFF3DDC84),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
