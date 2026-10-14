import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Rock {
  _Rock(this.x, this.y, this.r, this.hp, this.speed) : maxHp = hp;

  double x;
  double y;
  final double r;
  int hp;
  final int maxHp;
  final double speed;
}

Color _rockBase(_Rock k) =>
    Color.lerp(const Color(0xFF6B7280), const Color(0xFFFF8A4D), 1 - k.hp / k.maxHp)!;

class _Bullet {
  _Bullet(this.x, this.y);

  final double x;
  double y;
}

/// Gemiyi sürükle, otomatik ateş et. Asteroitleri vur, çarpmaktan kaç. 3 can.
class StarBlasterScreen extends StatefulWidget {
  const StarBlasterScreen({super.key});

  @override
  State<StarBlasterScreen> createState() => _StarBlasterScreenState();
}

class _StarBlasterScreenState extends State<StarBlasterScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'star_blaster';
  static const double _shipR = 16;
  static const double _lift = 50;
  static const double _bulletSpeed = 640;
  static const double _fireEvery = 0.26;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Rock> _rocks = [];
  final List<_Bullet> _bullets = [];
  double _w = 0;
  double _h = 0;
  double _sx = -1;
  double _sy = -1;
  double _fire = 0;
  double _spawn = 0;
  double _time = 0;
  double _invuln = 0;
  int _lives = 3;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

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
      _rocks.clear();
      _bullets.clear();
      _sx = -1;
      _sy = -1;
      _fire = 0;
      _spawn = 0.6;
      _time = 0;
      _invuln = 0;
      _lives = 3;
      _score = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    if (_sx < 0) {
      _sx = _w / 2;
      _sy = _h * 0.82;
    }
    _time += dt;
    if (_invuln > 0) _invuln -= dt;

    // Otomatik ateş
    _fire -= dt;
    if (_fire <= 0) {
      _fire = _fireEvery;
      _bullets.add(_Bullet(_sx, _sy - _shipR));
    }

    // Asteroit üret
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = math.max(0.32, 0.95 - _time * 0.012);
      final r = 16 + _rnd.nextDouble() * 20;
      var hp = 1 + (r > 26 ? 1 : 0) + (_time > 35 ? 1 : 0);
      if (_time > 70 && r > 32) hp++;
      final speed = math.min(280.0, 90 + _time * 2.5) * (0.85 + _rnd.nextDouble() * 0.5);
      _rocks.add(_Rock(r + _rnd.nextDouble() * (_w - r * 2), -r, r, hp, speed));
    }

    // Hareket
    for (final b in _bullets) {
      b.y -= _bulletSpeed * dt;
    }
    _bullets.removeWhere((b) => b.y < -10);
    for (final k in _rocks) {
      k.y += k.speed * dt;
    }

    // Mermi - asteroit
    final deadBullets = <_Bullet>[];
    final deadRocks = <_Rock>[];
    for (final b in _bullets) {
      for (final k in _rocks) {
        if (deadRocks.contains(k)) continue;
        final dx = b.x - k.x;
        final dy = b.y - k.y;
        if (dx * dx + dy * dy <= k.r * k.r) {
          deadBullets.add(b);
          k.hp--;
          if (k.hp <= 0) {
            deadRocks.add(k);
            _score += 10 + k.maxHp * 5;
            Sfx.correct();
          }
          break;
        }
      }
    }
    _bullets.removeWhere(deadBullets.contains);
    _rocks.removeWhere(deadRocks.contains);

    // Gemi - asteroit
    if (_invuln <= 0) {
      for (final k in _rocks) {
        final dx = _sx - k.x;
        final dy = _sy - k.y;
        final rr = k.r + _shipR * 0.8;
        if (dx * dx + dy * dy < rr * rr) {
          _lives--;
          _invuln = 1.4;
          _rocks.remove(k);
          HapticFeedback.heavyImpact();
          Sfx.wrong();
          if (_lives <= 0) {
            _finish();
            return;
          }
          break;
        }
      }
    }

    // Aşağı kaçanlar
    _rocks.removeWhere((k) => k.y > _h + k.r + 10);
    setState(() {});
  }

  void _move(Offset p) {
    if (_over || _w <= 0) return;
    _sx = p.dx.clamp(_shipR, _w - _shipR).toDouble();
    _sy = (p.dy - _lift).clamp(_h * 0.35, _h - _shipR - 4).toDouble();
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
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
    final blink = _invuln > 0 && ((_invuln * 10).floor() % 2 == 0);
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
                    label: t.p('Star Blaster', 'Yıldız Avcısı'),
                    score: _score,
                    lives: _lives,
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
                                for (final k in _rocks)
                                  Positioned(
                                    left: k.x - k.r,
                                    top: k.y - k.r,
                                    child: Container(
                                      width: k.r * 2,
                                      height: k.r * 2,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        gradient: RadialGradient(
                                          center: const Alignment(-0.4, -0.45),
                                          colors: [
                                            Color.lerp(_rockBase(k), Colors.white, 0.35)!,
                                            _rockBase(k),
                                            Color.lerp(_rockBase(k), Colors.black, 0.4)!,
                                          ],
                                          stops: const [0, 0.5, 1],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: _rockBase(k).withAlpha(k.maxHp > 1 ? 80 : 40),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: k.maxHp > 1
                                          ? Text(
                                              '${k.hp}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ),
                                for (final b in _bullets)
                                  Positioned(
                                    left: b.x - 2,
                                    top: b.y - 8,
                                    child: Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [Colors.white, Color(0xFFFFC94D)],
                                        ),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: const [
                                          BoxShadow(color: Color(0xAAFFC94D), blurRadius: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_sx >= 0 && !blink)
                                  Positioned(
                                    left: _sx - _shipR,
                                    top: _sy - _shipR,
                                    child: const Icon(
                                      Icons.navigation_rounded,
                                      size: _shipR * 2,
                                      color: AppColors.accent,
                                      shadows: [
                                        Shadow(color: Color(0xCCFF5E7E), blurRadius: 16),
                                      ],
                                    ),
                                  ),
                                if (_time < 2.5)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 24,
                                    child: Text(
                                      t.p('Drag to fly — it fires itself',
                                          'Sürükleyerek uç — kendiliğinden ateş eder'),
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
