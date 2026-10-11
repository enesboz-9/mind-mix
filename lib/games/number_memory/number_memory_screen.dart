import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/l10n.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _numColor = Color(0xFFE879F9);

enum _Phase { show, input, reveal }

/// Sayıyı kısa süre göster, sonra klavyeden geri yazmanı iste.
/// Her doğru cevapta sayı bir hane uzar.
class NumberMemoryScreen extends StatefulWidget {
  const NumberMemoryScreen({super.key});

  @override
  State<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends State<NumberMemoryScreen> {
  static const String _id = 'number_memory';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  _Phase _phase = _Phase.show;
  String _target = '';
  String _typed = '';
  bool _wasCorrect = false;
  int _level = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  int _roundId = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _digits => _level + 2;
  int get _showMs => 900 + _digits * 450;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _newRound() {
    _timer?.cancel();
    final buf = StringBuffer();
    for (var i = 0; i < _digits; i++) {
      buf.write(_rnd.nextInt(10));
    }
    setState(() {
      _target = buf.toString();
      _typed = '';
      _phase = _Phase.show;
      _roundId++;
    });
    _timer = Timer(Duration(milliseconds: _showMs), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.input);
    });
  }

  void _start() {
    _timer?.cancel();
    _level = 1;
    _lives = _maxLives;
    _score = 0;
    _over = false;
    _isNewBest = false;
    _newRound();
  }

  void _press(String d) {
    if (_phase != _Phase.input || _typed.length >= _digits) return;
    HapticFeedback.selectionClick();
    setState(() => _typed += d);
    if (_typed.length == _digits) _submit();
  }

  void _backspace() {
    if (_phase != _Phase.input || _typed.isEmpty) return;
    setState(() => _typed = _typed.substring(0, _typed.length - 1));
  }

  void _submit() {
    final ok = _typed == _target;
    if (ok) {
      Sfx.correct();
      setState(() {
        _wasCorrect = true;
        _phase = _Phase.reveal;
        _score += _digits * 10;
        _level++;
      });
      _timer = Timer(const Duration(milliseconds: 800), () {
        if (mounted) _newRound();
      });
    } else {
      Sfx.wrong();
      HapticFeedback.heavyImpact();
      setState(() {
        _wasCorrect = false;
        _phase = _Phase.reveal;
        _lives--;
      });
      _timer = Timer(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        if (_lives <= 0) {
          _finish();
        } else {
          _newRound();
        }
      });
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _center(AppStrings t) {
    switch (_phase) {
      case _Phase.show:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.p('Memorize it', 'Aklında tut'),
              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
            ),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _target,
                style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: _numColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_roundId),
                tween: Tween<double>(begin: 1, end: 0),
                duration: Duration(milliseconds: _showMs),
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                  color: _numColor,
                  backgroundColor: AppColors.surface,
                ),
              ),
            ),
          ],
        );
      case _Phase.input:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.p('Type the number', 'Sayıyı yaz'),
              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _digits; i++)
                  Container(
                    width: 38,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: i == _typed.length ? _numColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      i < _typed.length ? _typed[i] : '',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ],
        );
      case _Phase.reveal:
        final color = _wasCorrect ? AppColors.good : AppColors.bad;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _wasCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: color,
              size: 40,
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _target,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: color,
                ),
              ),
            ),
            if (!_wasCorrect) ...[
              const SizedBox(height: 8),
              Text(
                t.p('You typed: $_typed', 'Yazdığın: $_typed'),
                style: const TextStyle(color: AppColors.textDim, fontSize: 15),
              ),
            ],
          ],
        );
    }
  }

  Widget _keypad() {
    final on = _phase == _Phase.input;

    Widget key(Widget child, VoidCallback? onTap) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: SizedBox(
            height: 56,
            child: FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    Widget digit(String d) => key(
          Text(d, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          on ? () => _press(d) : null,
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [digit('1'), digit('2'), digit('3')]),
            Row(children: [digit('4'), digit('5'), digit('6')]),
            Row(children: [digit('7'), digit('8'), digit('9')]),
            Row(
              children: [
                key(const Icon(Icons.backspace_rounded), on ? _backspace : null),
                digit('0'),
                const Expanded(child: SizedBox(height: 66)),
              ],
            ),
          ],
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
                extra: t.p('Longest number: ${_level + 1} digits', 'En uzun sayı: ${_level + 1} hane'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('$_digits digits', '$_digits hane'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: _center(t),
                      ),
                    ),
                  ),
                  Center(child: _keypad()),
                ],
              ),
      ),
    );
  }
}
