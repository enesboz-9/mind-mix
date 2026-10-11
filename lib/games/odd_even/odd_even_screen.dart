import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Tek mi çift mi? Arada "Ters gün" başlar: cevaplar tersine verilir! 3 can.
class OddEvenScreen extends StatefulWidget {
  const OddEvenScreen({super.key});

  @override
  State<OddEvenScreen> createState() => _OddEvenScreenState();
}

class _OddEvenScreenState extends State<OddEvenScreen> {
  static const String _id = 'odd_even';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _expire;

  int _itemId = 0;
  int _number = 0;
  bool _flip = false;
  int _lives = _maxLives;
  int _correct = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _correct * 10;
  int get _durMs => math.max(1000, 2600 - _correct * 40);

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
      _correct = 0;
      _flip = false;
      _over = false;
      _isNewBest = false;
    });
    _next();
  }

  void _next() {
    _expire?.cancel();
    final max = math.min(99, 20 + _correct * 3);
    setState(() {
      _number = 1 + _rnd.nextInt(max);
      _itemId++;
    });
    _expire = Timer(Duration(milliseconds: _durMs), _miss);
  }

  /// [even] = oyuncunun bastığı düğme "ÇİFT" mi?
  void _answer(bool even) {
    if (_over) return;
    final shouldBeEven = _number.isEven != _flip;
    if (even == shouldBeEven) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      _correct++;
      // Her 5 doğruda kural değişebilir.
      if (_correct % 5 == 0 && _correct >= 5) _flip = _rnd.nextBool();
      _next();
    } else {
      _miss();
    }
  }

  void _miss() {
    if (!mounted || _over) return;
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    _lives--;
    if (_lives <= 0) {
      _finish();
    } else {
      _next();
    }
  }

  Future<void> _finish() async {
    _expire?.cancel();
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

  Widget _button(String label, Color color, bool even) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          ),
          onPressed: () => _answer(even),
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
                extra: t.p('Correct answers: $_correct', 'Doğru cevap: $_correct'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Correct $_correct', 'Doğru $_correct'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey<int>(_itemId),
                        tween: Tween<double>(begin: 1, end: 0),
                        duration: Duration(milliseconds: _durMs),
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          color: AppColors.accent,
                          backgroundColor: AppColors.surface,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: _flip ? AppColors.bad : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _flip
                            ? t.p('OPPOSITE DAY! Tap the wrong one', 'TERS GÜN! Yanlış olana bas')
                            : t.p('Is it odd or even?', 'Tek mi çift mi?'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Text(
                        '$_number',
                        style: const TextStyle(fontSize: 120, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      child: Row(
                        children: [
                          _button(t.p('ODD', 'TEK'), const Color(0xFF4D9DFF), false),
                          _button(t.p('EVEN', 'ÇİFT'), const Color(0xFFA472EE), true),
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
