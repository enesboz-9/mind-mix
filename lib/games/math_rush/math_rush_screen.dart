import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Hızlı işlemler. 45 saniye ve 3 can; zorluk doğru cevaplarla artar.
class MathRushScreen extends StatefulWidget {
  const MathRushScreen({super.key});

  @override
  State<MathRushScreen> createState() => _MathRushScreenState();
}

class _MathRushScreenState extends State<MathRushScreen> {
  static const String _id = 'math_rush';
  static const int _totalMs = 45000;
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _timeMs = _totalMs;
  int _lives = _maxLives;
  int _score = 0;
  int _solved = 0;
  int _streak = 0;
  int _best = 0;
  String _question = '';
  int _answer = 0;
  List<int> _options = const [];
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
      _newQuestion();
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

  void _newQuestion() {
    final d = _solved;
    final maxN = math.min(60, 9 + d * 2);
    final op = d < 3 ? _rnd.nextInt(2) : _rnd.nextInt(3);
    int a;
    int b;
    switch (op) {
      case 0:
        a = 1 + _rnd.nextInt(maxN);
        b = 1 + _rnd.nextInt(maxN);
        _answer = a + b;
        _question = '$a + $b';
      case 1:
        a = 2 + _rnd.nextInt(maxN);
        b = 1 + _rnd.nextInt(a - 1);
        _answer = a - b;
        _question = '$a − $b';
      default:
        final m = math.min(12, 3 + d ~/ 3);
        a = 2 + _rnd.nextInt(m);
        b = 2 + _rnd.nextInt(m);
        _answer = a * b;
        _question = '$a × $b';
    }
    final set = <int>{_answer};
    while (set.length < 4) {
      final cand = _answer + _rnd.nextInt(21) - 10;
      if (cand >= 0) set.add(cand);
    }
    _options = set.toList()..shuffle(_rnd);
  }

  void _pick(int value) {
    if (_over) return;
    if (value == _answer) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _score += 10 + math.min(_streak, 10) * 2;
        _streak++;
        _solved++;
        _newQuestion();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives--;
      _streak = 0;
      if (_lives <= 0) {
        _finish();
      } else {
        setState(_newQuestion);
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

  Widget _optionButton(int value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () => _pick(value),
          child: Text('$value', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
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
                extra: t.p('Solved: $_solved', 'Çözülen: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Solved $_solved', 'Çözülen $_solved'),
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
                      child: Text(
                        '$_question = ?',
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(children: [_optionButton(_options[0]), _optionButton(_options[1])]),
                          ),
                          Expanded(
                            child: Row(children: [_optionButton(_options[2]), _optionButton(_options[3])]),
                          ),
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
