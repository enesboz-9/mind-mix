import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Nokta halkada dönüyor; yeşil bölgedeyken ekrana dokun. Her isabette yön
/// değişir, nokta hızlanır, bölge daralır. Bölgeyi dokunmadan geçersen ya da
/// boşa dokunursan can gider. 3 can.
class OrbitTapScreen extends StatefulWidget {
  const OrbitTapScreen({super.key});

  @override
  State<OrbitTapScreen> createState() => _OrbitTapScreenState();
}

class _OrbitTapScreenState extends State<OrbitTapScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'orbit_tap';
  static const int _maxLives = 3;
  static const double _twoPi = math.pi * 2;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  double _angle = -math.pi / 2;
  double _zone = 0;
  double _dir = 1;
  double _wait = 0.7;
  bool _wasInZone = false;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  Color _flash = Colors.transparent;

  double get _speed => math.min(7.0, 2.2 + _score * 0.12);
  double get _arc => math.max(0.45, 1.1 - _score * 0.035);

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
      _angle = -math.pi / 2;
      _dir = 1;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _flash = Colors.transparent;
      _newZone();
    });
    _loop.start();
  }

  double _wrap(double x) {
    var v = x % _twoPi;
    if (v > math.pi) v -= _twoPi;
    return v;
  }

  bool get _inZone => _wrap(_angle - _zone).abs() <= _arc / 2;

  /// Yeni bölge, noktanın gittiği yönde biraz ilerisinde olsun.
  void _newZone() {
    _zone = _angle + _dir * (1.4 + _rnd.nextDouble() * 3.0);
    _wait = 0.5;
    _wasInZone = false;
  }

  void _tick(double dt) {
    if (_over) return;
    if (_wait > 0) {
      _wait -= dt;
      if (_wait <= 0) setState(() => _flash = Colors.transparent);
      return;
    }
    _angle += _dir * _speed * dt;
    final now = _inZone;
    if (_wasInZone && !now) {
      _miss();
      return;
    }
    _wasInZone = now;
    setState(() {});
  }

  void _tap() {
    if (_over || _wait > 0) return;
    if (_inZone) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _score++;
        _dir = -_dir;
        _flash = AppColors.good.withAlpha(40);
        _newZone();
      });
    } else {
      _miss();
    }
  }

  void _miss() {
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    _lives--;
    if (_lives <= 0) {
      _lives = 0;
      _finish();
      return;
    }
    setState(() {
      _flash = AppColors.bad.withAlpha(40);
      _newZone();
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
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Tap in the green zone', 'Yeşil bölgede dokun'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _tap(),
                      child: Container(
                        color: _flash,
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final side = math.min(box.maxWidth, box.maxHeight) - 40;
                            return Center(
                              child: CustomPaint(
                                size: Size(side, side),
                                painter: _OrbitPainter(
                                  angle: _angle,
                                  zone: _zone,
                                  arc: _arc,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({required this.angle, required this.zone, required this.arc});

  final double angle;
  final double zone;
  final double arc;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..color = AppColors.surface,
    );
    canvas.drawArc(
      rect,
      zone - arc / 2,
      arc,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..color = AppColors.good,
    );
    final dot = Offset(
      center.dx + radius * math.cos(angle),
      center.dy + radius * math.sin(angle),
    );
    canvas.drawCircle(dot, 13, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => true;
}
