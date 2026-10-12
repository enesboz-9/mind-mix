import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Wall {
  _Wall(this.x, this.w, this.h, this.onFloor);

  double x; // sol kenar
  final double w;
  final double h;
  final bool onFloor;
}

/// Ekrana dokun, yer çekimi yön değiştirsin. Zeminden ve tavandan çıkan
/// engellere çarpma. Tek can.
class GravityFlipScreen extends StatefulWidget {
  const GravityFlipScreen({super.key});

  @override
  State<GravityFlipScreen> createState() => _GravityFlipScreenState();
}

class _GravityFlipScreenState extends State<GravityFlipScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'gravity_flip';
  static const double _size = 28;
  static const double _margin = 30; // zemin ve tavan çizgisi kalınlığı
  static const double _flipSeconds = 0.26; // bir yüzeyden diğerine geçiş süresi

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Wall> _walls = [];
  double _w = 0;
  double _h = 0;
  double _y = -1; // oyuncunun üst kenarı
  int _dir = 1; // 1: aşağı (zemin), -1: yukarı (tavan)
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
      _walls.clear();
      _y = -1;
      _dir = 1;
      _spawn = 1.0;
      _time = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  double get _floorTop => _h - _margin;
  double get _ceilBottom => _margin;
  double get _travel => _floorTop - _ceilBottom - _size;

  void _flip() {
    if (_over) return;
    HapticFeedback.selectionClick();
    _dir = -_dir;
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    if (_y < 0) _y = _floorTop - _size;
    _time += dt;

    final speed = math.min(520.0, 250 + _time * 6);
    final px = _w * 0.22;

    // Oyuncu hareketi
    final vy = _travel / _flipSeconds;
    _y += _dir * vy * dt;
    _y = _y.clamp(_ceilBottom, _floorTop - _size).toDouble();

    // Engel üret
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.75, 1.35 - _time * 0.008) + _rnd.nextDouble() * 0.5;
      final wallW = 24 + _rnd.nextDouble() * 22;
      final wallH = 34 + _rnd.nextDouble() * 40;
      _walls.add(_Wall(_w + 10, wallW, wallH, _rnd.nextBool()));
    }

    var hit = false;
    for (final k in _walls) {
      k.x -= speed * dt;
      final top = k.onFloor ? _floorTop - k.h : _ceilBottom;
      // Biraz af payı bırak
      const pad = 3.0;
      final overlapX = px + _size - pad > k.x && px + pad < k.x + k.w;
      final overlapY = _y + _size - pad > top && _y + pad < top + k.h;
      if (overlapX && overlapY) hit = true;
    }
    _walls.removeWhere((k) => k.x + k.w < -10);

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
                    label: t.p('Gravity Flip', 'Yerçekimi'),
                    score: _score,
                    timeText: '${_time.toStringAsFixed(1)}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        _w = box.maxWidth;
                        _h = box.maxHeight;
                        final px = _w * 0.22;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _flip(),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                // Tavan ve zemin
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 0,
                                  height: _margin,
                                  child: Container(color: AppColors.surface),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  height: _margin,
                                  child: Container(color: AppColors.surface),
                                ),
                                for (final k in _walls)
                                  Positioned(
                                    left: k.x,
                                    top: k.onFloor ? _h - _margin - k.h : _margin,
                                    child: Container(
                                      width: k.w,
                                      height: k.h,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF4D4D),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                if (_y >= 0)
                                  Positioned(
                                    left: px,
                                    top: _y,
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
                                    bottom: 48,
                                    child: Text(
                                      t.p('Tap to flip gravity', 'Yerçekimini çevirmek için dokun'),
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
