import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _orderColor = Color(0xFF818CF8);

/// Karışık dizilmiş sayılara 1'den başlayarak sırayla dokun.
/// Süre dolarsa ya da yanlış sayıya basarsan can gider.
class NumberOrderScreen extends StatefulWidget {
  const NumberOrderScreen({super.key});

  @override
  State<NumberOrderScreen> createState() => _NumberOrderScreenState();
}

class _NumberOrderScreenState extends State<NumberOrderScreen> {
  static const String _id = 'number_order';
  static const int _maxLives = 3;
  static const List<int> _colsPerRound = [3, 3, 4, 4, 5, 5];

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  List<int> _numbers = [];
  int _next = 1;
  int _round = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  int _msLeft = 0;
  int _totalMs = 1;
  bool _over = false;
  bool _isNewBest = false;

  int get _cols => _colsPerRound[math.min(_round - 1, _colsPerRound.length - 1)];
  int get _cells => _cols * _cols;

  @override
  void initState() {
    super.initState();
    _deal();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  /// Yeni tahta dağıtır ve geri sayımı başlatır (setState çağırmaz).
  void _deal() {
    _ticker?.cancel();
    _numbers = [for (var i = 1; i <= _cells; i++) i]..shuffle(_rnd);
    _next = 1;
    _totalMs = _cells * math.max(800, 1300 - _round * 40);
    _msLeft = _totalMs;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || _over) return;
      setState(() => _msLeft -= 100);
      if (_msLeft <= 0) _onTimeout();
    });
  }

  void _start() {
    setState(() {
      _round = 1;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _deal();
    });
  }

  void _onTimeout() {
    Sfx.wrong();
    HapticFeedback.heavyImpact();
    setState(() => _lives--);
    if (_lives <= 0) {
      _finish();
    } else {
      setState(_deal);
    }
  }

  void _tapNumber(int n) {
    if (_over) return;
    if (n == _next) {
      HapticFeedback.selectionClick();
      setState(() => _next++);
      if (_next > _cells) {
        Sfx.correct();
        setState(() {
          _score += _cells;
          _round++;
          _deal();
        });
      }
    } else if (n > _next) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() => _lives--);
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
                extra: t.p('Boards cleared: ${_round - 1}', 'Biten tur: ${_round - 1}'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Next: $_next', 'Sıradaki: $_next'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: LinearProgressIndicator(
                      value: (_msLeft / _totalMs).clamp(0.0, 1.0),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(3),
                      color: _msLeft / _totalMs < 0.25 ? AppColors.bad : _orderColor,
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: GridView.count(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          crossAxisCount: _cols,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            for (final n in _numbers)
                              GestureDetector(
                                onTap: () => _tapNumber(n),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: n < _next
                                        ? Colors.transparent
                                        : _orderColor.withAlpha(50),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: n < _next
                                          ? AppColors.surface
                                          : _orderColor.withAlpha(140),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '$n',
                                    style: TextStyle(
                                      fontSize: _cols >= 5 ? 20 : 26,
                                      fontWeight: FontWeight.w800,
                                      color: n < _next
                                          ? AppColors.surface
                                          : Colors.white,
                                    ),
                                  ),
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
