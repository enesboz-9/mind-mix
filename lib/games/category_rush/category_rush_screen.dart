import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Category {
  const _Category(this.nameEn, this.nameTr, this.items);

  final String nameEn;
  final String nameTr;
  final List<String> items;
}

class _Pair {
  const _Pair(this.left, this.right);

  final _Category left;
  final _Category right;
}

/// Ekrandaki emoji hangi kategoriye ait? Sol ya da sağ düğmeye bas. 40 saniye,
/// 3 can; her 6 doğruda kategori çifti değişir, seri yaptıkça puan artar.
class CategoryRushScreen extends StatefulWidget {
  const CategoryRushScreen({super.key});

  @override
  State<CategoryRushScreen> createState() => _CategoryRushScreenState();
}

class _CategoryRushScreenState extends State<CategoryRushScreen> {
  static const String _id = 'category_rush';
  static const int _totalSeconds = 40;
  static const int _maxLives = 3;
  static const int _perPair = 6;
  static const Color _leftColor = Color(0xFF4D9DFF);
  static const Color _rightColor = Color(0xFFFF8A4D);

  static const List<_Pair> _pairs = [
    _Pair(
      _Category('Animal', 'Hayvan', ['🐶', '🐱', '🐼', '🦁', '🐸', '🐵', '🐧', '🐘']),
      _Category('Food', 'Yemek', ['🍕', '🍔', '🍟', '🌮', '🍩', '🍪', '🍣', '🥪']),
    ),
    _Pair(
      _Category('Fruit', 'Meyve', ['🍎', '🍌', '🍇', '🍓', '🍉', '🍍', '🥭', '🍒']),
      _Category('Vegetable', 'Sebze', ['🥕', '🥦', '🌽', '🍆', '🥒', '🥔', '🧅', '🥬']),
    ),
    _Pair(
      _Category('On the ground', 'Karada', ['🚗', '🚌', '🚲', '🚂', '🚜', '🏍️']),
      _Category('In the air', 'Havada', ['✈️', '🚁', '🚀', '🛸', '🎈', '🪂']),
    ),
    _Pair(
      _Category('Hot', 'Sıcak', ['🔥', '☀️', '🌋', '☕', '🏜️', '🌡️']),
      _Category('Cold', 'Soğuk', ['❄️', '🧊', '⛄', '🥶', '🏔️', '🍦']),
    ),
  ];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _pairIndex = 0;
  int _correctInPair = 0;
  String _emoji = '';
  bool _answerLeft = true;
  String _lastEmoji = '';

  int _left = _totalSeconds;
  int _lives = _maxLives;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  bool _newPairFlash = false;
  bool _over = false;
  bool _isNewBest = false;

  _Pair get _pair => _pairs[_pairIndex % _pairs.length];

  @override
  void initState() {
    super.initState();
    _nextItem();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _start() {
    setState(() {
      _left = _totalSeconds;
      _lives = _maxLives;
      _score = 0;
      _streak = 0;
      _pairIndex = 0;
      _correctInPair = 0;
      _newPairFlash = false;
      _over = false;
      _isNewBest = false;
      _nextItem();
    });
    _startTimer();
  }

  void _nextItem() {
    _answerLeft = _rnd.nextBool();
    final items = (_answerLeft ? _pair.left : _pair.right).items;
    var e = items[_rnd.nextInt(items.length)];
    while (e == _lastEmoji && items.length > 1) {
      e = items[_rnd.nextInt(items.length)];
    }
    _emoji = e;
    _lastEmoji = e;
  }

  void _answer(bool left) {
    if (_over) return;
    final ok = left == _answerLeft;
    HapticFeedback.selectionClick();
    setState(() {
      _newPairFlash = false;
      if (ok) {
        _streak++;
        _score += 10 + math.min(_streak - 1, 10) * 2;
        _correctInPair++;
        if (_correctInPair >= _perPair) {
          _correctInPair = 0;
          _pairIndex++;
          _newPairFlash = true;
        }
      } else {
        _streak = 0;
        _lives--;
      }
    });
    if (ok) {
      Sfx.correct();
    } else {
      Sfx.wrong();
      if (_lives <= 0) {
        _finish();
        return;
      }
    }
    setState(_nextItem);
  }

  Future<void> _finish() async {
    if (_over) return;
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

  Widget _button(String label, Color color, bool left) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _answer(left),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
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
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Streak $_streak', 'Seri $_streak'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_left}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _newPairFlash
                          ? t.p('New categories!', 'Yeni kategoriler!')
                          : t.p('Which category?', 'Hangi kategori?'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _newPairFlash ? AppColors.good : AppColors.textDim,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(_emoji, style: const TextStyle(fontSize: 120)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    child: Row(
                      children: [
                        _button(t.p(_pair.left.nameEn, _pair.left.nameTr), _leftColor, true),
                        const SizedBox(width: 14),
                        _button(t.p(_pair.right.nameEn, _pair.right.nameTr), _rightColor, false),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
