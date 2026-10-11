import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// N-Back: Gelen şekil bir (sonra iki) önceki şekille aynı mı? 3 can.
class BackMemoryScreen extends StatefulWidget {
  const BackMemoryScreen({super.key});

  @override
  State<BackMemoryScreen> createState() => _BackMemoryScreenState();
}

class _BackMemoryScreenState extends State<BackMemoryScreen> {
  static const String _id = 'back_memory';
  static const int _maxLives = 3;
  static const List<IconData> _icons = [
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.cloud_rounded,
    Icons.bolt_rounded,
    Icons.diamond_rounded,
    Icons.eco_rounded,
  ];
  static const List<Color> _colors = [
    Color(0xFFFFC94D),
    Color(0xFFFF5E7E),
    Color(0xFF4D9DFF),
    Color(0xFFFF9F43),
    Color(0xFFA472EE),
    Color(0xFF3DDC84),
  ];

  final math.Random _rnd = math.Random();
  Timer? _expire;

  final List<int> _hist = [];
  int _itemId = 0;
  int _lives = _maxLives;
  int _correct = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _n => _correct >= 8 ? 2 : 1;
  int get _durMs => math.max(1400, 2800 - _correct * 35);
  int get _score => _correct * 10;
  bool get _canAnswer => _hist.length > _n;
  bool get _isMatch => _canAnswer && _hist.last == _hist[_hist.length - 1 - _n];

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
      _hist.clear();
      _lives = _maxLives;
      _correct = 0;
      _over = false;
      _isNewBest = false;
    });
    _next();
  }

  void _next() {
    _expire?.cancel();
    final n = _n;
    int s;
    if (_hist.length >= n && _rnd.nextDouble() < 0.4) {
      s = _hist[_hist.length - n];
    } else {
      s = _rnd.nextInt(_icons.length);
    }
    setState(() {
      _hist.add(s);
      _itemId++;
    });
    _expire = Timer(Duration(milliseconds: _durMs), _onTimeout);
  }

  void _onTimeout() {
    if (!mounted || _over) return;
    if (!_canAnswer) {
      _next(); // ilk şekiller sadece ezberlenir
    } else {
      _miss();
    }
  }

  void _answer(bool same) {
    if (_over || !_canAnswer) return;
    if (same == _isMatch) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      _correct++;
      _next();
    } else {
      _miss();
    }
  }

  void _miss() {
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
          onPressed: _canAnswer ? () => _answer(value) : null,
          child: Text(label, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final n = _n;
    final symbol = _hist.isEmpty ? 0 : _hist.last;
    final question = n == 1
        ? t.p('Same as the previous one?', 'Bir öncekiyle aynı mı?')
        : t.p('Same as 2 shapes ago?', 'İki önceki şekille aynı mı?');
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
                    label: '$n-Back',
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
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      _canAnswer ? question : t.p('Memorize…', 'Aklında tut…'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: Icon(_icons[symbol], size: 110, color: _colors[symbol]),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      child: Row(
                        children: [
                          _answerButton(t.p('DIFFERENT', 'FARKLI'), AppColors.bad, false),
                          _answerButton(t.p('SAME', 'AYNI'), const Color(0xFF2FB36B), true),
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
