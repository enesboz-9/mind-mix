import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Gidip gelen işareti yeşil alanın içinde durdur. Alan daralır, işaret hızlanır.
/// Tam ortaya yakın vuruşlar bonus verir. 3 can.
class TimingBarScreen extends StatefulWidget {
  const TimingBarScreen({super.key});

  @override
  State<TimingBarScreen> createState() => _TimingBarScreenState();
}

class _TimingBarScreenState extends State<TimingBarScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'timing_bar';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  double _center = 0.5;
  int _hits = 0;
  int _perfects = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _lastPerfect = false;

  int get _score => _hits * 10 + _perfects * 5;
  double get _zoneW => math.max(0.08, 0.30 - _hits * 0.015);
  int get _periodMs => math.max(700, 1800 - _hits * 60);

  @override
  void initState() {
    super.initState();
    _newZone();
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _newZone() {
    final w = _zoneW;
    _center = w / 2 + 0.02 + _rnd.nextDouble() * (1 - w - 0.04);
  }

  void _start() {
    setState(() {
      _hits = 0;
      _perfects = 0;
      _lives = _maxLives;
      _over = false;
      _isNewBest = false;
      _lastPerfect = false;
      _newZone();
    });
    _ctrl.duration = Duration(milliseconds: _periodMs);
    _ctrl.repeat(reverse: true);
  }

  void _tap() {
    if (_over) return;
    final pos = _ctrl.value;
    final dist = (pos - _center).abs();
    final hit = dist <= _zoneW / 2;
    if (hit) {
      final perfect = dist <= _zoneW * 0.1;
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        if (perfect) _perfects++;
        _lastPerfect = perfect;
        _hits++;
        _newZone();
      });
      _ctrl.duration = Duration(milliseconds: _periodMs);
      _ctrl.repeat(reverse: true);
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _lastPerfect = false;
      });
      if (_lives <= 0) _finish();
    }
  }

  Future<void> _finish() async {
    _ctrl.stop();
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
                extra: t.p('Perfect hits: $_perfects', 'Tam vuruş: $_perfects'),
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
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _tap(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                t.p(
                                  'Tap anywhere when the marker\nis inside the green zone',
                                  'İşaret yeşil alandayken\nekrana dokun',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.textDim,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 24,
                                child: _lastPerfect
                                    ? Text(
                                        t.p('Perfect! +5', 'Tam isabet! +5'),
                                        style: const TextStyle(
                                          color: AppColors.good,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              LayoutBuilder(
                                builder: (context, box) {
                                  final w = box.maxWidth;
                                  return SizedBox(
                                    height: 64,
                                    width: w,
                                    child: Stack(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        Positioned(
                                          left: (_center - _zoneW / 2) * w,
                                          width: _zoneW * w,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.good.withAlpha(110),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: AppColors.good, width: 2),
                                            ),
                                          ),
                                        ),
                                        AnimatedBuilder(
                                          animation: _ctrl,
                                          builder: (context, _) => Positioned(
                                            left: _ctrl.value * w - 3,
                                            width: 6,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
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
