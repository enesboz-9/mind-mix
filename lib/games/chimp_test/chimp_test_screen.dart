import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _chimpColor = Color(0xFFF9A8D4);

/// Maymun testi: sayılar ekranda görünür, 1'e dokununca diğerleri gizlenir.
/// Sayıların yerini hatırlayıp 1'den başlayarak sırayla dokun. 3 can.
class ChimpTestScreen extends StatefulWidget {
  const ChimpTestScreen({super.key});

  @override
  State<ChimpTestScreen> createState() => _ChimpTestScreenState();
}

class _ChimpTestScreenState extends State<ChimpTestScreen> {
  static const String _id = 'chimp_test';
  static const int _maxLives = 3;
  static const int _cols = 5;
  static const int _rows = 6;
  static const int _cells = _cols * _rows;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<int> _num = List<int>.filled(_cells, 0);
  List<bool> _gone = List<bool>.filled(_cells, false);
  int _level = 1;
  int _next = 1;
  bool _hidden = false;
  bool _reveal = false;
  bool _busy = false;
  int _wrongIdx = -1;
  int _score = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _count => math.min(_level + 3, 20);

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  /// Yeni tahtayı hazırlar (setState çağırmaz).
  void _deal() {
    _num = List<int>.filled(_cells, 0);
    _gone = List<bool>.filled(_cells, false);
    final order = List<int>.generate(_cells, (i) => i)..shuffle(_rnd);
    for (var n = 1; n <= _count; n++) {
      _num[order[n - 1]] = n;
    }
    _next = 1;
    _hidden = false;
    _reveal = false;
    _busy = false;
    _wrongIdx = -1;
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _level = 1;
      _score = 0;
      _lives = _maxLives;
      _over = false;
      _isNewBest = false;
      _deal();
    });
  }

  void _tap(int i) {
    if (_busy || _over) return;
    if (_num[i] == 0 || _gone[i]) return;
    if (_num[i] == _next) {
      HapticFeedback.selectionClick();
      setState(() {
        _gone[i] = true;
        _hidden = true;
        _next++;
      });
      if (_next > _count) {
        Sfx.correct();
        setState(() {
          _score += _count * 10;
          _level++;
          _deal();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _busy = true;
      setState(() {
        _lives--;
        _reveal = true;
        _wrongIdx = i;
      });
      _timer = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        if (_lives <= 0) {
          _finish();
        } else {
          setState(_deal);
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

  Widget _cell(int i) {
    if (_num[i] == 0 || _gone[i]) return const SizedBox.shrink();
    final showNumber = !_hidden || _reveal;
    final wrong = _reveal && i == _wrongIdx;
    final color = wrong ? AppColors.bad : _chimpColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(i),
      child: Container(
        margin: const EdgeInsets.all(4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withAlpha(showNumber ? 50 : 110),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha(170), width: 2),
        ),
        child: showNumber
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_num[i]}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              )
            : null,
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
                extra: t.p('Reached $_count numbers', '$_count sayıya ulaşıldı'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.p('Tap the numbers in order from 1', "1'den başlayarak sırayla dokun"),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final w = math.min(box.maxWidth, 360.0);
                          final h = math.min(box.maxHeight, w * _rows / _cols);
                          return Center(
                            child: SizedBox(
                              width: math.min(w, h * _cols / _rows),
                              height: h,
                              child: Column(
                                children: [
                                  for (var r = 0; r < _rows; r++)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (var c = 0; c < _cols; c++)
                                            Expanded(child: _cell(r * _cols + c)),
                                        ],
                                      ),
                                    ),
                                ],
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
