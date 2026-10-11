import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _cmpColor = Color(0xFFF472B6);

class _Expr {
  const _Expr(this.text, this.value);

  final String text;
  final int value;
}

/// İki işlemden sonucu büyük olanı seç. 30 saniye, 3 can.
class QuickCompareScreen extends StatefulWidget {
  const QuickCompareScreen({super.key});

  @override
  State<QuickCompareScreen> createState() => _QuickCompareScreenState();
}

class _QuickCompareScreenState extends State<QuickCompareScreen> {
  static const String _id = 'quick_compare';
  static const int _maxLives = 3;
  static const int _totalSeconds = 30;

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  _Expr _a = const _Expr('1 + 1', 2);
  _Expr _b = const _Expr('1 + 2', 3);
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

  _Expr _makeExpr() {
    final lvl = math.min(_hits ~/ 5, 3);
    final op = _rnd.nextInt(lvl == 0 ? 1 : (lvl == 1 ? 2 : 3));
    if (op == 0) {
      final m = 10 + lvl * 10;
      final x = 2 + _rnd.nextInt(m);
      final y = 2 + _rnd.nextInt(m);
      return _Expr('$x + $y', x + y);
    } else if (op == 1) {
      final x = 10 + _rnd.nextInt(20 + lvl * 15);
      final y = 1 + _rnd.nextInt(x - 1);
      return _Expr('$x - $y', x - y);
    } else {
      final m = 5 + lvl * 2;
      final x = 2 + _rnd.nextInt(m);
      final y = 2 + _rnd.nextInt(m);
      return _Expr('$x × $y', x * y);
    }
  }

  /// Yeni çift hazırlar (setState çağırmaz).
  void _pick() {
    _a = _makeExpr();
    do {
      _b = _makeExpr();
    } while (_b.value == _a.value);
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

  void _choose(bool left) {
    if (_over) return;
    final correct = left ? _a.value > _b.value : _b.value > _a.value;
    if (correct) {
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

  Widget _option(String text, bool left) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 140,
          child: FilledButton.tonal(
            onPressed: () => _choose(left),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              backgroundColor: _cmpColor.withAlpha(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
            ),
          ),
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
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p('Which one is bigger?', 'Hangisi daha büyük?'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 440),
                              child: Row(
                                children: [
                                  _option(_a.text, true),
                                  _option(_b.text, false),
                                ],
                              ),
                            ),
                          ],
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
