import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Eşitlik doğru mu yanlış mı? 40 saniye, 3 can; seri yaptıkça puan artar.
class TrueFalseScreen extends StatefulWidget {
  const TrueFalseScreen({super.key});

  @override
  State<TrueFalseScreen> createState() => _TrueFalseScreenState();
}

class _TrueFalseScreenState extends State<TrueFalseScreen> {
  static const String _id = 'true_false';
  static const int _totalMs = 40000;
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _timeMs = _totalMs;
  int _lives = _maxLives;
  int _score = 0;
  int _solved = 0;
  int _streak = 0;
  int _best = 0;
  String _equation = '';
  bool _isTrue = true;
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
      _timeMs = _totalMs;
      _lives = _maxLives;
      _score = 0;
      _solved = 0;
      _streak = 0;
      _over = false;
      _isNewBest = false;
      _newEquation();
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

  void _newEquation() {
    final d = _solved;
    final maxN = math.min(80, 12 + d * 2);
    final op = d < 3 ? _rnd.nextInt(2) : _rnd.nextInt(3);
    int a;
    int b;
    int result;
    String sym;
    switch (op) {
      case 0:
        a = 2 + _rnd.nextInt(maxN);
        b = 2 + _rnd.nextInt(maxN);
        result = a + b;
        sym = '+';
      case 1:
        a = 3 + _rnd.nextInt(maxN);
        b = 1 + _rnd.nextInt(a - 1);
        result = a - b;
        sym = '−';
      default:
        final m = math.min(12, 4 + d ~/ 3);
        a = 2 + _rnd.nextInt(m);
        b = 2 + _rnd.nextInt(m);
        result = a * b;
        sym = '×';
    }
    _isTrue = _rnd.nextBool();
    var shown = result;
    if (!_isTrue) {
      const offsets = [-10, -3, -2, -1, 1, 2, 3, 10];
      final k = offsets[_rnd.nextInt(offsets.length)];
      shown = result + k;
      if (shown < 0) shown = result + k.abs();
    }
    _equation = '$a $sym $b = $shown';
  }

  void _answer(bool says) {
    if (_over) return;
    if (says == _isTrue) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _score += 10 + math.min(_streak, 10) * 2;
        _streak++;
        _solved++;
        _newEquation();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives--;
      _streak = 0;
      if (_lives <= 0) {
        _finish();
      } else {
        setState(_newEquation);
      }
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timeMs = math.max(0, _timeMs);
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

  Widget _answerButton(String label, Color color, bool value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () => _answer(value),
          child: Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        ),
      ),
    );
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
                extra: t.p('Answered: $_solved', 'Doğru cevap: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Correct $_solved', 'Doğru $_solved'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
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
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _equation,
                            style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      child: Row(
                        children: [
                          _answerButton(t.p('FALSE', 'YANLIŞ'), AppColors.bad, false),
                          _answerButton(t.p('TRUE', 'DOĞRU'), const Color(0xFF2FB36B), true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
