import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Block {
  _Block(this.x, this.y, this.size, this.speedMul);

  final double x; // sol kenar, piksel
  double y; // üst kenar, piksel
  final double size;
  final double speedMul;
}

/// Parmağınla noktayı sürükle, düşen bloklardan kaç. Tek can.
class DodgeRushScreen extends StatefulWidget {
  const DodgeRushScreen({super.key});

  @override
  State<DodgeRushScreen> createState() => _DodgeRushScreenState();
}

class _DodgeRushScreenState extends State<DodgeRushScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'dodge_rush';
  static const double _r = 12;
  static const double _lift = 44; // nokta parmağın üstünde dursun

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Block> _blocks = [];
  double _w = 0;
  double _h = 0;
  double _px = -1;
  double _py = -1;
  double _spawn = 0;
  double _time = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => (_time * 10).floor();

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
      _blocks.clear();
      _px = -1;
      _py = -1;
      _spawn = 0.5;
      _time = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    if (_px < 0) {
      _px = _w / 2;
      _py = _h * 0.78;
    }
    _time += dt;
    final speed = math.min(520.0, 230.0 + _time * 7);
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.22, 0.75 - _time * 0.012);
      final size = 26 + _rnd.nextDouble() * 50;
      _blocks.add(_Block(
        _rnd.nextDouble() * (_w - size),
        -size,
        size,
        0.8 + _rnd.nextDouble() * 0.5,
      ));
    }
    var hit = false;
    for (final b in _blocks) {
      b.y += speed * b.speedMul * dt;
      // Daire - dikdörtgen çarpışması
      final cx = _px.clamp(b.x, b.x + b.size).toDouble();
      final cy = _py.clamp(b.y, b.y + b.size).toDouble();
      final dx = _px - cx;
      final dy = _py - cy;
      if (dx * dx + dy * dy < _r * _r) hit = true;
    }
    _blocks.removeWhere((b) => b.y > _h + 10);
    if (hit) {
      _finish();
      return;
    }
    setState(() {});
  }

  void _move(Offset p) {
    if (_over || _w <= 0) return;
    _px = p.dx.clamp(_r, _w - _r).toDouble();
    _py = (p.dy - _lift).clamp(_r, _h - _r).toDouble();
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
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
                extra: t.p(
                  'Survived: ${_time.toStringAsFixed(1)} s',
                  'Hayatta kalma: ${_time.toStringAsFixed(1)} sn',
                ),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Dodge', 'Kaç'),
                    score: _score,
                    timeText: '${_time.toStringAsFixed(1)}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _w = box.maxWidth;
                        _h = box.maxHeight;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanDown: (d) => _move(d.localPosition),
                          onPanUpdate: (d) => _move(d.localPosition),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                for (final b in _blocks)
                                  Positioned(
                                    left: b.x,
                                    top: b.y,
                                    child: Container(
                                      width: b.size,
                                      height: b.size,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFC94D),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                if (_px >= 0)
                                  Positioned(
                                    left: _px - _r,
                                    top: _py - _r,
                                    child: Container(
                                      width: _r * 2,
                                      height: _r * 2,
                                      decoration: const BoxDecoration(
                                        color: AppColors.accent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                if (_time < 2)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 24,
                                    child: Text(
                                      t.p('Drag to move', 'Sürükleyerek hareket et'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.white54),
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
