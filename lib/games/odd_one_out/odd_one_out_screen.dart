import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Izgarada tek farklı tonu bul. 30 saniye, yanlış dokunuş 3 saniye götürür.
class OddOneOutScreen extends StatefulWidget {
  const OddOneOutScreen({super.key});

  @override
  State<OddOneOutScreen> createState() => _OddOneOutScreenState();
}

class _OddOneOutScreenState extends State<OddOneOutScreen> {
  static const String _id = 'odd_one_out';
  static const int _totalMs = 30000;
  static const int _penaltyMs = 3000;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _level = 1;
  int _score = 0;
  int _timeMs = _totalMs;
  int _gridSize = 2;
  int _oddIndex = 0;
  int _best = 0;
  Color _base = AppColors.accent;
  Color _odd = AppColors.accent;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    _timer?.cancel();
    setState(() {
      _level = 1;
      _score = 0;
      _timeMs = _totalMs;
      _over = false;
      _isNewBest = false;
      _newRound();
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _timeMs -= 100;
      if (_timeMs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _newRound() {
    _gridSize = math.min(6, 2 + (_level + 1) ~/ 3);
    final h = _rnd.nextDouble() * 360;
    final s = 0.45 + _rnd.nextDouble() * 0.35;
    final l = 0.40 + _rnd.nextDouble() * 0.2;
    final diff = math.max(0.035, 0.22 - _level * 0.012);
    final dir = _rnd.nextBool() ? 1.0 : -1.0;
    _base = HSLColor.fromAHSL(1, h, s, l).toColor();
    _odd = HSLColor.fromAHSL(1, h, s, (l + dir * diff).clamp(0.05, 0.95).toDouble()).toColor();
    _oddIndex = _rnd.nextInt(_gridSize * _gridSize);
  }

  void _tap(int i) {
    if (_over) return;
    if (i == _oddIndex) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _score += 10;
        _level++;
        _newRound();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _timeMs -= _penaltyMs;
      if (_timeMs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timeMs = 0;
      _over = true;
    });
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
                extra: t.p('Level reached: $_level', 'Ulaşılan seviye: $_level'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    timeText: '${(_timeMs / 1000).ceil()}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_timeMs / _totalMs).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      t.p('Tap the different one', 'Farklı olanı bul'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(box.maxWidth, box.maxHeight);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: GridView.count(
                                crossAxisCount: _gridSize,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                physics: const NeverScrollableScrollPhysics(),
                                children: List.generate(_gridSize * _gridSize, (i) {
                                  return GestureDetector(
                                    onTap: () => _tap(i),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: i == _oddIndex ? _odd : _base,
                                        borderRadius: BorderRadius.circular(
                                          math.max(6.0, 22.0 - _gridSize * 2),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
