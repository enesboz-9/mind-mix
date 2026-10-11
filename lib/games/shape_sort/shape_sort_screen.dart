import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Şekli, düğmenin üzerindeki şekle göre sola ya da sağa gönder.
/// Her 8 doğruda kural yer değiştirir. 30 saniye, 3 can.
class ShapeSortScreen extends StatefulWidget {
  const ShapeSortScreen({super.key});

  @override
  State<ShapeSortScreen> createState() => _ShapeSortScreenState();
}

class _ShapeSortScreenState extends State<ShapeSortScreen> {
  static const String _id = 'shape_sort';
  static const int _maxLives = 3;
  static const int _totalSeconds = 30;
  static const List<Color> _palette = [
    Color(0xFFFF5E7E),
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFFC94D),
    Color(0xFFA472EE),
  ];

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  bool _isCircle = true;
  bool _circleLeft = true;
  bool _justSwapped = false;
  int _colorIdx = 0;
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
    _isCircle = _rnd.nextBool();
    _colorIdx = _rnd.nextInt(_palette.length);
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _circleLeft = true;
      _justSwapped = false;
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

  void _answer(bool left) {
    if (_over) return;
    final shouldGoLeft = _isCircle == _circleLeft;
    if (left == shouldGoLeft) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _justSwapped = false;
        if (_hits % 8 == 0) {
          _circleLeft = !_circleLeft;
          _justSwapped = true;
        }
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

  Widget _shape(bool circle, double size, Color color, {bool outline = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: outline ? Colors.transparent : color,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.18),
        border: outline ? Border.all(color: color, width: 3) : null,
      ),
    );
  }

  Widget _sideButton({required bool left}) {
    final circle = left ? _circleLeft : !_circleLeft;
    final arrow = Icon(
      left ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
      size: 28,
    );
    final shape = _shape(circle, 28, Colors.white, outline: true);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 84,
          child: FilledButton.tonal(
            onPressed: () => _answer(left),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: left
                  ? [arrow, const SizedBox(width: 12), shape]
                  : [shape, const SizedBox(width: 12), arrow],
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _justSwapped
                                ? t.p('Rule changed!', 'Kural değişti!')
                                : t.p('Send the shape to its side', 'Şekli kendi tarafına gönder'),
                            style: TextStyle(
                              color: _justSwapped ? AppColors.accent : AppColors.textDim,
                              fontSize: 16,
                              fontWeight: _justSwapped ? FontWeight.w800 : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 28),
                          _shape(_isCircle, 120, _palette[_colorIdx]),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Row(
                        children: [
                          _sideButton(left: true),
                          _sideButton(left: false),
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
