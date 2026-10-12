import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Dizideki bir sonraki sayıyı bul. 3 can; her doğru cevapta kurallar zorlaşır.
class NextNumberScreen extends StatefulWidget {
  const NextNumberScreen({super.key});

  @override
  State<NextNumberScreen> createState() => _NextNumberScreenState();
}

class _NextNumberScreenState extends State<NextNumberScreen> {
  static const String _id = 'next_number';

  final math.Random _rnd = math.Random();

  List<int> _shown = [];
  int _answer = 0;
  List<int> _options = [];
  int? _picked;
  int _lives = 3;
  int _score = 0;
  int _solved = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _lives = 3;
      _score = 0;
      _solved = 0;
      _over = false;
      _isNewBest = false;
    });
    _next();
  }

  /// 6 terimlik bir dizi üretir (son terim cevaptır).
  List<int> _makeSequence() {
    final kinds = math.min(6, 2 + _solved ~/ 3);
    final kind = _rnd.nextInt(kinds);
    final seq = <int>[];
    switch (kind) {
      case 0: // aritmetik
        final a = 1 + _rnd.nextInt(20);
        var d = 2 + _rnd.nextInt(8);
        if (_solved >= 6 && _rnd.nextBool()) d = -d;
        for (var i = 0; i < 6; i++) {
          seq.add(a + d * i);
        }
        break;
      case 1: // geometrik
        final a = 1 + _rnd.nextInt(5);
        final r = 2 + _rnd.nextInt(2);
        var v = a;
        for (var i = 0; i < 6; i++) {
          seq.add(v);
          v *= r;
        }
        break;
      case 2: // kareler
        final k = 1 + _rnd.nextInt(6);
        for (var i = 0; i < 6; i++) {
          seq.add((k + i) * (k + i));
        }
        break;
      case 3: // dönüşümlü artış
        final s = 1 + _rnd.nextInt(10);
        final a = 1 + _rnd.nextInt(5);
        var b = 2 + _rnd.nextInt(8);
        if (b == a) b++;
        var v = s;
        for (var i = 0; i < 6; i++) {
          seq.add(v);
          v += i.isEven ? a : b;
        }
        break;
      case 4: // artan farklar
        final s = 1 + _rnd.nextInt(10);
        final d = 1 + _rnd.nextInt(3);
        var v = s;
        for (var i = 0; i < 6; i++) {
          seq.add(v);
          v += d + i;
        }
        break;
      default: // fibonacci benzeri
        final x = 1 + _rnd.nextInt(4);
        final y = 1 + _rnd.nextInt(5);
        seq.addAll([x, y]);
        for (var i = 2; i < 6; i++) {
          seq.add(seq[i - 1] + seq[i - 2]);
        }
    }
    return seq;
  }

  void _next() {
    final seq = _makeSequence();
    final answer = seq.last;
    final opts = <int>{answer};
    var guard = 0;
    while (opts.length < 4 && guard < 200) {
      guard++;
      final off = 1 + _rnd.nextInt(10);
      final cand = answer + (_rnd.nextBool() ? off : -off);
      if (cand == answer) continue;
      opts.add(cand);
    }
    var fill = 1;
    while (opts.length < 4) {
      opts.add(answer + 11 + fill++);
    }
    final list = opts.toList()..shuffle(_rnd);
    setState(() {
      _shown = seq.sublist(0, 5);
      _answer = answer;
      _options = list;
      _picked = null;
      _locked = false;
    });
  }

  Future<void> _answerTap(int v) async {
    if (_locked || _over) return;
    _locked = true;
    setState(() => _picked = v);
    if (v == _answer) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _solved++;
        _score += 10;
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() => _lives--);
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_lives <= 0) {
      await _finish();
    } else {
      _next();
    }
  }

  Future<void> _finish() async {
    Sfx.over();
    setState(() => _over = true);
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Color _optionColor(int o) {
    if (_picked == null) return AppColors.surface;
    if (o == _answer) return AppColors.good;
    if (o == _picked) return AppColors.bad;
    return AppColors.surface;
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
                extra: t.p('Sequences solved: $_solved', 'Çözülen dizi: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Next Number', 'Sıradaki Sayı'),
                    score: _score,
                    lives: _lives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p('What comes next?', 'Sırada hangi sayı var?'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                [..._shown.map((e) => '$e'), '?'].join(',  '),
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final o in _options)
                                  SizedBox(
                                    width: 120,
                                    height: 72,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _optionColor(o),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: () => _answerTap(o),
                                      child: Text(
                                        '$o',
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
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
                  ),
                ],
              ),
      ),
    );
  }
}
