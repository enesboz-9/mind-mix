import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Beliren daireye süresi dolmadan dokun. Kaçırırsan can gider, süre kısalır.
class TapRushScreen extends StatefulWidget {
  const TapRushScreen({super.key});

  @override
  State<TapRushScreen> createState() => _TapRushScreenState();
}

class _TapRushScreenState extends State<TapRushScreen> {
  static const String _id = 'tap_rush';
  static const int _maxLives = 3;
  static const double _size = 88;

  final math.Random _rnd = math.Random();
  Timer? _expire;

  int _lives = _maxLives;
  int _hits = 0;
  int _best = 0;
  int _targetId = 0;
  double _fx = 0.5;
  double _fy = 0.5;
  bool _over = false;
  bool _isNewBest = false;

  int get _durationMs => math.max(550, 1400 - _hits * 25);
  int get _score => _hits * 10;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _expire?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    _expire?.cancel();
    setState(() {
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
    });
    _nextTarget();
  }

  void _nextTarget() {
    _expire?.cancel();
    setState(() {
      _targetId++;
      _fx = _rnd.nextDouble();
      _fy = _rnd.nextDouble();
    });
    _expire = Timer(Duration(milliseconds: _durationMs), _onMiss);
  }

  void _onHit() {
    if (_over) return;
    HapticFeedback.selectionClick();
    Sfx.correct();
    _hits++;
    _nextTarget();
  }

  void _onMiss() {
    if (!mounted || _over) return;
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    _lives--;
    if (_lives <= 0) {
      _finish();
    } else {
      _nextTarget();
    }
  }

  Future<void> _finish() async {
    _expire?.cancel();
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
                extra: t.p('Targets hit: $_hits', 'Vurulan hedef: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Hits $_hits', 'Vuruş $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final left = _fx * (box.maxWidth - _size);
                        final top = _fy * (box.maxHeight - _size);
                        return Stack(
                          children: [
                            Positioned(
                              left: left,
                              top: top,
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey<int>(_targetId),
                                tween: Tween<double>(begin: 1.0, end: 0.45),
                                duration: Duration(milliseconds: _durationMs),
                                builder: (context, value, _) {
                                  return SizedBox(
                                    width: _size,
                                    height: _size,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Süre halkası: hedef küçüldükçe içindeki disk halkaya yaklaşır.
                                        Container(
                                          width: _size * 0.5,
                                          height: _size * 0.5,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withAlpha(60),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTapDown: (_) => _onHit(),
                                          child: Container(
                                            width: _size * value,
                                            height: _size * value,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: const RadialGradient(
                                                center: Alignment(-0.3, -0.35),
                                                colors: [Color(0xFFFFB3C1), AppColors.accent],
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Color(0x99FF5E7E),
                                                  blurRadius: 22,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                            child: Center(
                                              child: Container(
                                                width: _size * value * 0.28,
                                                height: _size * value * 0.28,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white,
                                                ),
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
