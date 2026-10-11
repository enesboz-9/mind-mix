import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Yeşil ok: oku gösterdiği yöne bas. Kırmızı ok: TERS yöne bas. 30 saniye.
class ArrowRuleScreen extends StatefulWidget {
  const ArrowRuleScreen({super.key});

  @override
  State<ArrowRuleScreen> createState() => _ArrowRuleScreenState();
}

class _ArrowRuleScreenState extends State<ArrowRuleScreen> {
  static const String _id = 'arrow_rule';
  static const int _maxLives = 3;
  static const int _totalSeconds = 30;

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  /// 0 yukarı, 1 sağ, 2 aşağı, 3 sol
  int _dir = 0;
  bool _opposite = false;
  int _secs = _totalSeconds;
  int _lives = _maxLives;
  int _hits = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _pick() {
    _dir = _rnd.nextInt(4);
    _opposite = _rnd.nextBool();
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
      _pick();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _secs--);
      if (_secs <= 0) _finish();
    });
  }

  void _press(int d) {
    if (_over) return;
    final expected = _opposite ? (_dir + 2) % 4 : _dir;
    if (d == expected) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _pick();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _pick();
      });
      if (_lives <= 0) _finish();
    }
  }

  Future<void> _finish() async {
    if (_over) return;
    _ticker?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _pad(int d, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        width: 80,
        height: 80,
        child: FilledButton.tonal(
          onPressed: () => _press(d),
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          ),
          child: Icon(icon, size: 36),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final arrowColor = _opposite ? AppColors.bad : AppColors.good;
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Correct answers: $_hits', 'Doğru cevap: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Correct $_hits', 'Doğru $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_secs}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 15,
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: t.p('Green', 'Yeşil'),
                                  style: const TextStyle(
                                    color: AppColors.good,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: t.p(' = same way\n', ' = aynı yön\n')),
                                TextSpan(
                                  text: t.p('Red', 'Kırmızı'),
                                  style: const TextStyle(
                                    color: AppColors.bad,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: t.p(' = opposite way', ' = ters yön')),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          Transform.rotate(
                            angle: _dir * math.pi / 2,
                            child: Icon(Icons.arrow_upward_rounded, size: 120, color: arrowColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _pad(0, Icons.arrow_upward_rounded),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _pad(3, Icons.arrow_back_rounded),
                            const SizedBox(width: 90),
                            _pad(1, Icons.arrow_forward_rounded),
                          ],
                        ),
                        _pad(2, Icons.arrow_downward_rounded),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
