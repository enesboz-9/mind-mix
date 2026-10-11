import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Yanıp sönen sırayı izle, aynı sırayı tekrar et. Yanlış = oyun biter.
class SequenceEchoScreen extends StatefulWidget {
  const SequenceEchoScreen({super.key});

  @override
  State<SequenceEchoScreen> createState() => _SequenceEchoScreenState();
}

class _SequenceEchoScreenState extends State<SequenceEchoScreen> {
  static const String _id = 'sequence_echo';
  static const List<Color> _colors = [
    Color(0xFFFF4D6D),
    Color(0xFF3DDC84),
    Color(0xFF4D9DFF),
    Color(0xFFFFC94D),
  ];

  final math.Random _rnd = math.Random();
  final List<int> _seq = [];

  int _token = 0;
  int _inputIdx = 0;
  int _rounds = 0;
  int _best = 0;
  int? _lit;
  bool _watching = true;
  bool _over = false;
  bool _isNewBest = false;

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
      _seq.clear();
      _rounds = 0;
      _over = false;
      _isNewBest = false;
      _lit = null;
    });
    _nextRound();
  }

  Future<void> _nextRound() async {
    final token = ++_token;
    setState(() {
      _seq.add(_rnd.nextInt(4));
      _watching = true;
      _inputIdx = 0;
      _lit = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final step = math.max(200, 520 - _rounds * 25);
    for (final i in List<int>.of(_seq)) {
      if (!mounted || token != _token) return;
      setState(() => _lit = i);
      await Future<void>.delayed(Duration(milliseconds: step));
      if (!mounted || token != _token) return;
      setState(() => _lit = null);
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (!mounted || token != _token) return;
    setState(() => _watching = false);
  }

  void _tap(int i) {
    if (_watching || _over) return;
    setState(() => _lit = i);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted && _lit == i) setState(() => _lit = null);
    });
    if (_seq[_inputIdx] == i) {
      HapticFeedback.selectionClick();
      _inputIdx++;
      if (_inputIdx == _seq.length) {
        _rounds++;
        Sfx.correct();
        _nextRound();
      }
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    _token++;
    HapticFeedback.heavyImpact();
    Sfx.over();
    setState(() {
      _over = true;
      _lit = null;
    });
    final r = await ScoreStore.record(_id, _rounds * 10);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _pad(int i) {
    final c = _colors[i];
    final on = _lit == i;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: GestureDetector(
          onTap: () => _tap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: on ? c : c.withAlpha(90),
              borderRadius: BorderRadius.circular(28),
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
                score: _rounds * 10,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Rounds completed: $_rounds', 'Tamamlanan tur: $_rounds'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Round ${_rounds + 1}', 'Tur ${_rounds + 1}'),
                    score: _rounds * 10,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _watching ? t.p('Watch…', 'İzle…') : t.p('Your turn', 'Sıra sende'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _watching ? AppColors.textDim : AppColors.good,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(box.maxWidth, box.maxHeight);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Column(
                                children: [
                                  Expanded(child: Row(children: [_pad(0), _pad(1)])),
                                  Expanded(child: Row(children: [_pad(2), _pad(3)])),
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
