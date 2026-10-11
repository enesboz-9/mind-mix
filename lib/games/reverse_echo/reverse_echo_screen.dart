import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Yanan sırayı izle, TERSTEN tekrar et. Yanlış = oyun biter.
class ReverseEchoScreen extends StatefulWidget {
  const ReverseEchoScreen({super.key});

  @override
  State<ReverseEchoScreen> createState() => _ReverseEchoScreenState();
}

class _ReverseEchoScreenState extends State<ReverseEchoScreen> {
  static const String _id = 'reverse_echo';
  static const List<Color> _colors = [
    Color(0xFFFF5E7E),
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFFC94D),
  ];

  final math.Random _rnd = math.Random();

  final List<int> _seq = [];
  int _token = 0; // eski bekleyen animasyonları iptal etmek için
  int _lit = -1;
  int _pos = 0;
  int _rounds = 0;
  int _best = 0;
  bool _showing = true;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _rounds * 10 + (_rounds > 1 ? (_rounds - 1) * 2 : 0);

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
      _seq
        ..clear()
        ..addAll([_rnd.nextInt(4), _rnd.nextInt(4)]);
      _rounds = 0;
      _over = false;
      _isNewBest = false;
    });
    _play();
  }

  Future<void> _play() async {
    final token = ++_token;
    setState(() {
      _showing = true;
      _lit = -1;
      _pos = 0;
    });
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (final p in List<int>.of(_seq)) {
      if (!mounted || token != _token) return;
      setState(() => _lit = p);
      await Future<void>.delayed(const Duration(milliseconds: 480));
      if (!mounted || token != _token) return;
      setState(() => _lit = -1);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted || token != _token) return;
    setState(() => _showing = false);
  }

  Future<void> _flash(int p) async {
    final token = _token;
    setState(() => _lit = p);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted || token != _token) return;
    setState(() => _lit = -1);
  }

  void _tap(int p) {
    if (_over || _showing) return;
    final expected = _seq[_seq.length - 1 - _pos];
    if (p != expected) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    Sfx.correct();
    _flash(p);
    _pos++;
    if (_pos >= _seq.length) {
      setState(() {
        _rounds++;
        _seq.add(_rnd.nextInt(4));
      });
      _play();
    } else {
      setState(() {});
    }
  }

  Future<void> _finish() async {
    _token++;
    HapticFeedback.heavyImpact();
    Sfx.wrong();
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
                extra: t.p('Rounds cleared: $_rounds', 'Geçilen tur: $_rounds'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Length ${_seq.length}', 'Uzunluk ${_seq.length}'),
                    score: _score,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      _showing
                          ? t.p('Watch…', 'İzle…')
                          : t.p('Now repeat it BACKWARDS', 'Şimdi TERSTEN tekrar et'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(box.maxWidth, box.maxHeight);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: GridView.count(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                physics: const NeverScrollableScrollPhysics(),
                                children: List.generate(4, (i) {
                                  final on = _lit == i;
                                  return GestureDetector(
                                    onTapDown: (_) => _tap(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 90),
                                      decoration: BoxDecoration(
                                        color: on ? _colors[i] : _colors[i].withAlpha(70),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  );
                                }),
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
