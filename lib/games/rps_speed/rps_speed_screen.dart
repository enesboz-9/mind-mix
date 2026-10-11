import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Taş-kâğıt-makas refleksi: rakibin hamlesini YEN ya da KAYBET! 3 can.
class RpsSpeedScreen extends StatefulWidget {
  const RpsSpeedScreen({super.key});

  @override
  State<RpsSpeedScreen> createState() => _RpsSpeedScreenState();
}

class _RpsSpeedScreenState extends State<RpsSpeedScreen> {
  static const String _id = 'rps_speed';
  static const int _maxLives = 3;
  // 0 taş, 1 kâğıt, 2 makas. x'i yenen hamle: (x + 1) % 3.
  static const List<String> _emoji = ['✊', '✋', '✌️'];

  final math.Random _rnd = math.Random();
  Timer? _expire;

  int _itemId = 0;
  int _opp = 0;
  bool _mustWin = true;
  int _lives = _maxLives;
  int _correct = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _correct * 10;
  int get _durMs => math.max(1100, 2800 - _correct * 45);

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
      _over = false;
      _isNewBest = false;
    });
    _next();
  }

  void _next() {
    _expire?.cancel();
    setState(() {
      _opp = _rnd.nextInt(3);
      _mustWin = _correct < 3 ? true : _rnd.nextBool();
      _itemId++;
    });
    _expire = Timer(Duration(milliseconds: _durMs), _miss);
  }

  void _pick(int move) {
    if (_over) return;
    final target = _mustWin ? (_opp + 1) % 3 : (_opp + 2) % 3;
    if (move == target) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      _correct++;
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                      decoration: BoxDecoration(
                        color: _mustWin ? const Color(0xFF2FB36B) : AppColors.bad,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _mustWin ? t.p('BEAT IT!', 'YEN!') : t.p('LOSE TO IT!', 'KAYBET!'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Center(
                      child: Text(_emoji[_opp], style: const TextStyle(fontSize: 120)),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                      child: Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.surface,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  onPressed: () => _pick(i),
                                  child: FittedBox(
                                    child: Text(_emoji[i], style: const TextStyle(fontSize: 44)),
                                  ),
                                ),
                              ),
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
