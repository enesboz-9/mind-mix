import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Birbirine benzeyen harflerden oluşan tabloda farklı olanı bul.
/// Tablo büyüdükçe zorlaşır. 30 saniye, 3 can.
class LetterHuntScreen extends StatefulWidget {
  const LetterHuntScreen({super.key});

  @override
  State<LetterHuntScreen> createState() => _LetterHuntScreenState();
}

class _LetterHuntScreenState extends State<LetterHuntScreen> {
  static const String _id = 'letter_hunt';
  static const int _maxLives = 3;
  static const int _totalSeconds = 30;
  static const List<List<String>> _pairs = [
    ['O', 'Q'],
    ['b', 'd'],
    ['p', 'q'],
    ['M', 'N'],
    ['E', 'F'],
    ['C', 'G'],
    ['W', 'V'],
    ['U', 'V'],
    ['R', 'P'],
  ];

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  int _n = 3;
  String _base = 'O';
  String _odd = 'Q';
  int _oddIndex = 0;
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

  void _deal() {
    _n = math.min(3 + _hits ~/ 3, 7);
    final pair = _pairs[_rnd.nextInt(_pairs.length)];
    final swap = _rnd.nextBool();
    _base = pair[swap ? 1 : 0];
    _odd = pair[swap ? 0 : 1];
    _oddIndex = _rnd.nextInt(_n * _n);
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
      _deal();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _secs--);
      if (_secs <= 0) _finish();
    });
  }

  void _tap(int i) {
    if (_over) return;
    if (i == _oddIndex) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _deal();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _deal();
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

  Widget _grid(double side) {
    return SizedBox(
      width: side,
      height: side,
      child: Column(
        children: [
          for (var r = 0; r < _n; r++)
            Expanded(
              child: Row(
                children: [
                  for (var c = 0; c < _n; c++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _tap(r * _n + c),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                r * _n + c == _oddIndex ? _odd : _base,
                                style: TextStyle(
                                  fontSize: side / _n * 0.55,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
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
                extra: t.p('Letters found: $_hits', 'Bulunan harf: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Found $_hits', 'Bulunan $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_secs}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.p('Tap the odd letter', 'Farklı harfe dokun'),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(math.min(box.maxWidth, box.maxHeight), 360.0);
                          return Center(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: _grid(side - 16),
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
