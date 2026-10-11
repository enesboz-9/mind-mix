import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _patColor = Color(0xFF2DD4BF);

/// Sayı dizisindeki kuralı bul, sıradaki sayıyı seç. İlerledikçe kurallar zorlaşır.
class PatternFinderScreen extends StatefulWidget {
  const PatternFinderScreen({super.key});

  @override
  State<PatternFinderScreen> createState() => _PatternFinderScreenState();
}

class _PatternFinderScreenState extends State<PatternFinderScreen> {
  static const String _id = 'pattern_finder';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();

  List<int> _seq = [];
  List<int> _options = [];
  int _answer = 0;
  int? _missed;
  int _hits = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _close() => Navigator.of(context).pop();

  /// 5 terimlik bir dizi üretir; son terim cevaptır.
  List<int> _gen(int type) {
    final l = <int>[];
    if (type == 0) {
      // Sabit artış
      final a = 1 + _rnd.nextInt(20);
      final d = 2 + _rnd.nextInt(8);
      for (var i = 0; i < 5; i++) {
        l.add(a + d * i);
      }
    } else if (type == 1) {
      // Çarpan (2 veya 3 katı)
      final a = 1 + _rnd.nextInt(4);
      final r = 2 + _rnd.nextInt(2);
      var v = a;
      for (var i = 0; i < 5; i++) {
        l.add(v);
        v *= r;
      }
    } else if (type == 2) {
      // Dönüşümlü iki farklı artış
      final x = 1 + _rnd.nextInt(5);
      final y = 2 + _rnd.nextInt(6);
      l.add(1 + _rnd.nextInt(10));
      for (var i = 1; i < 5; i++) {
        l.add(l.last + (i.isOdd ? x : y));
      }
    } else if (type == 3) {
      // Artışın kendisi de artıyor
      final k = 1 + _rnd.nextInt(3);
      final inc = 1 + _rnd.nextInt(2);
      l.add(1 + _rnd.nextInt(10));
      for (var i = 1; i < 5; i++) {
        l.add(l.last + k + (i - 1) * inc);
      }
    } else {
      // Fibonacci tarzı: her terim öncekilerin toplamı
      l.add(1 + _rnd.nextInt(5));
      l.add(1 + _rnd.nextInt(5));
      for (var i = 2; i < 5; i++) {
        l.add(l[i - 1] + l[i - 2]);
      }
    }
    return l;
  }

  /// Yeni soru hazırlar (setState çağırmaz).
  void _next() {
    final available = math.min(5, 2 + _hits ~/ 3);
    final seq = _gen(_rnd.nextInt(available));
    _answer = seq.last;
    _seq = seq.sublist(0, seq.length - 1);

    final opts = <int>{_answer};
    final offs = List<int>.of(const [-3, -2, -1, 1, 2, 3, 4, -4, 5, 10])..shuffle(_rnd);
    for (final o in offs) {
      if (opts.length >= 4) break;
      opts.add(_answer + o);
    }
    _options = opts.toList()..shuffle(_rnd);
  }

  void _start() {
    setState(() {
      _hits = 0;
      _lives = _maxLives;
      _missed = null;
      _over = false;
      _isNewBest = false;
      _next();
    });
  }

  void _choose(int v) {
    if (_over) return;
    if (v == _answer) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _missed = null;
        _next();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _missed = _answer;
        _next();
      });
      if (_lives <= 0) _finish();
    }
  }

  Future<void> _finish() async {
    if (_over) return;
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _chip(String s, {bool question = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: question ? _patColor.withAlpha(40) : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: question ? _patColor : Colors.transparent, width: 2),
      ),
      child: Text(
        s,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: question ? _patColor : Colors.white,
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
                extra: t.p('Patterns solved: $_hits', 'Çözülen örüntü: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Solved $_hits', 'Çözülen $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p('What comes next?', 'Sıradaki sayı ne?'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final n in _seq) _chip('$n'),
                                _chip('?', question: true),
                              ],
                            ),
                            if (_missed != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                t.p('Last answer was $_missed', 'Önceki cevap $_missed idi'),
                                style: const TextStyle(color: AppColors.bad, fontSize: 14),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var row = 0; row < 2; row++)
                            Row(
                              children: [
                                for (var col = 0; col < 2; col++)
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: SizedBox(
                                        height: 64,
                                        child: FilledButton.tonal(
                                          onPressed: () => _choose(_options[row * 2 + col]),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${_options[row * 2 + col]}',
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
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
                ],
              ),
      ),
    );
  }
}
