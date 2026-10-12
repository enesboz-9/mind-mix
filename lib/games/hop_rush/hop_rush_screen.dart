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
  _Block(this.x, this.w, this.h);

  double x; // sol kenar
  final double w;
  final double h;
}

/// Dokun, zıpla. Koşarken gelen engellerin üzerinden atla. Tek can.
class HopRushScreen extends StatefulWidget {
  const HopRushScreen({super.key});

  @override
  State<HopRushScreen> createState() => _HopRushScreenState();
}

class _HopRushScreenState extends State<HopRushScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'hop_rush';
  static const double _size = 30;
  static const double _ground = 44; // zemin kalınlığı
  static const double _gravity = 1900;
  static const double _jumpV = 650;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Block> _blocks = [];
  double _w = 0;
  double _h = 0;
  double _py = 0; // zeminden yükseklik
  double _vy = 0;
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
      _py = 0;
      _vy = 0;
      _spawn = 1.0;
      _time = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _jump() {
    if (_over || _py > 0) return;
    HapticFeedback.selectionClick();
    _vy = _jumpV;
    _py = 0.001;
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    _time += dt;
    final speed = math.min(540.0, 270 + _time * 5);
    final px = _w * 0.2;

    if (_py > 0) {
      _vy -= _gravity * dt;
      _py += _vy * dt;
      if (_py <= 0) {
        _py = 0;
        _vy = 0;
      }
    }

    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.85, 1.5 - _time * 0.008) + _rnd.nextDouble() * 0.7;
      final bw = 22 + _rnd.nextDouble() * 18;
      final bh = 30 + _rnd.nextDouble() * 32;
      _blocks.add(_Block(_w + 10, bw, bh));
    }

    var hit = false;
    for (final k in _blocks) {
      k.x -= speed * dt;
      const pad = 4.0;
      final overlapX = px + _size - pad > k.x && px + pad < k.x + k.w;
      final overlapY = _py + pad < k.h;
      if (overlapX && overlapY) hit = true;
    }
    _blocks.removeWhere((k) => k.x + k.w < -10);

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
    Sfx.over();
    setState(() => _over = true);
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
                    label: t.p('Hop Rush', 'Zıpla Koş'),
                    score: _score,
                    timeText: '${_time.toStringAsFixed(1)}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _w = box.maxWidth;
                        _h = box.maxHeight;
                        final px = _w * 0.2;
                        final groundTop = _h - _ground;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _jump(),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: _ground,
                                  child: Container(color: AppColors.surface),
                                ),
                                for (final k in _blocks)
                                  Positioned(
                                    left: k.x,
                                    top: groundTop - k.h,
                                    child: Container(
                                      width: k.w,
                                      height: k.h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4D4D),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: px,
                                  top: groundTop - _py - _size,
                                  child: Container(
                                    width: _size,
                                    height: _size,
                                    decoration: BoxDecoration(
                                      color: AppColors.accent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                if (_time < 2.5)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 70,
                                    child: Text(
                                      t.p('Tap to jump', 'Zıplamak için dokun'),
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
