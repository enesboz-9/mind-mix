import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

enum _Phase { show, shuffle, pick, result }

/// Bardak oyunu: topun hangi bardağın altında olduğunu takip et. 3 can.
class ShellGameScreen extends StatefulWidget {
  const ShellGameScreen({super.key});

  @override
  State<ShellGameScreen> createState() => _ShellGameScreenState();
}

class _ShellGameScreenState extends State<ShellGameScreen> {
  static const String _id = 'shell_game';
  static const int _maxLives = 3;
  static const double _cupW = 84;
  static const double _cupH = 100;

  final math.Random _rnd = math.Random();

  List<int> _slotOf = [0, 1, 2]; // bardak -> yuva
  int _ball = 0;
  int _round = 0;
  int _token = 0;
  _Phase _phase = _Phase.show;
  int _picked = -1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _swapMs => math.max(170, 520 - _round * 30);
  int get _swaps => math.min(14, 4 + _round);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _token++;
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _slotOf = [0, 1, 2];
      _round = 0;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
    });
    _runRound();
  }

  Future<void> _runRound() async {
    final token = ++_token;
    setState(() {
      _ball = _rnd.nextInt(3);
      _picked = -1;
      _phase = _Phase.show;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted || token != _token) return;
    setState(() => _phase = _Phase.shuffle);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var k = 0; k < _swaps; k++) {
      if (!mounted || token != _token) return;
      final a = _rnd.nextInt(3);
      var b = _rnd.nextInt(3);
      if (b == a) b = (a + 1 + _rnd.nextInt(2)) % 3;
      setState(() {
        final next = List<int>.of(_slotOf);
        for (var c = 0; c < 3; c++) {
          if (_slotOf[c] == a) {
            next[c] = b;
          } else if (_slotOf[c] == b) {
            next[c] = a;
          }
        }
        _slotOf = next;
      });
      await Future<void>.delayed(Duration(milliseconds: _swapMs + 40));
    }
    if (!mounted || token != _token) return;
    setState(() => _phase = _Phase.pick);
  }

  Future<void> _pick(int cup) async {
    if (_phase != _Phase.pick || _over) return;
    final token = _token;
    final ok = cup == _ball;
    setState(() {
      _picked = cup;
      _phase = _Phase.result;
      if (ok) {
        _score += 10 + _round;
        _round++;
      } else {
        _lives--;
      }
    });
    if (ok) {
      HapticFeedback.selectionClick();
      Sfx.correct();
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
    }
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted || token != _token) return;
    if (_lives <= 0) {
      _finish();
    } else {
      _runRound();
    }
  }

  Future<void> _finish() async {
    _token++;
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
    final lifted = _phase == _Phase.show || _phase == _Phase.result;
    final msg = switch (_phase) {
      _Phase.show => t.p('Remember the ball…', 'Topu aklında tut…'),
      _Phase.shuffle => t.p('Follow the ball!', 'Topu takip et!'),
      _Phase.pick => t.p('Where is the ball?', 'Top nerede?'),
      _Phase.result => _picked == _ball
          ? t.p('Correct!', 'Doğru!')
          : t.p('Wrong cup!', 'Yanlış bardak!'),
    };
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Rounds won: $_round', 'Kazanılan tur: $_round'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_round + 1),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      msg,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final slotW = box.maxWidth / 3;
                        final top = box.maxHeight * 0.35;
                        double left(int slot) => slotW * slot + (slotW - _cupW) / 2;
                        return Stack(
                          children: [
                            // Top
                            Positioned(
                              left: left(_slotOf[_ball]) + _cupW / 2 - 14,
                              top: top + _cupH - 28,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: lifted ? 1 : 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                            for (var c = 0; c < 3; c++)
                              AnimatedPositioned(
                                duration: Duration(milliseconds: _swapMs),
                                curve: Curves.easeInOut,
                                left: left(_slotOf[c]),
                                top: top - ((lifted && (_phase == _Phase.show ? c == _ball : true)) ? 44 : 0),
                                child: GestureDetector(
                                  onTap: () => _pick(c),
                                  child: Container(
                                    width: _cupW,
                                    height: _cupH,
                                    decoration: BoxDecoration(
                                      color: (_phase == _Phase.result && c == _picked)
                                          ? (c == _ball ? const Color(0xFF2FB36B) : AppColors.bad)
                                          : AppColors.accent,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(18),
                                        topRight: Radius.circular(18),
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
