import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Ink {
  const _Ink(this.en, this.tr, this.color);

  final String en;
  final String tr;
  final Color color;
}

/// Stroop testi: kelimenin yazdığını değil, yazıldığı RENGİ seç. 30 saniye.
class ColorWordsScreen extends StatefulWidget {
  const ColorWordsScreen({super.key});

  @override
  State<ColorWordsScreen> createState() => _ColorWordsScreenState();
}

class _ColorWordsScreenState extends State<ColorWordsScreen> {
  static const String _id = 'color_words';
  static const int _maxLives = 3;
  static const int _totalSeconds = 30;
  static const List<_Ink> _inks = [
    _Ink('Red', 'Kırmızı', Color(0xFFFF4D4D)),
    _Ink('Blue', 'Mavi', Color(0xFF4D9DFF)),
    _Ink('Green', 'Yeşil', Color(0xFF3DDC84)),
    _Ink('Yellow', 'Sarı', Color(0xFFFFC94D)),
  ];

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  int _word = 0;
  int _ink = 1;
  int _left = _totalSeconds;
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

  void _pickWord() {
    _word = _rnd.nextInt(_inks.length);
    do {
      _ink = _rnd.nextInt(_inks.length);
    } while (_ink == _word);
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _left = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
      _pickWord();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _answer(int i) {
    if (_over) return;
    if (i == _ink) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _pickWord();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _pickWord();
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
                    timeText: '${_left}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p(
                                'Tap the COLOR of the word,\nnot what it says',
                                'Kelimenin yazdığını değil,\nRENGİNİ seç',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textDim,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                t.isTr ? _inks[_word].tr : _inks[_word].en,
                                style: TextStyle(
                                  fontSize: 60,
                                  fontWeight: FontWeight.w900,
                                  color: _inks[_ink].color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var row = 0; row < 2; row++)
                            Row(
                              children: [
                                for (var col = 0; col < 2; col++)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: SizedBox(
                                        height: 64,
                                        child: FilledButton.tonal(
                                          onPressed: () => _answer(row * 2 + col),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8),
                                              child: Text(
                                                t.isTr
                                                    ? _inks[row * 2 + col].tr
                                                    : _inks[row * 2 + col].en,
                                                style: const TextStyle(
                                                  fontSize: 19,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
