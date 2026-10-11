import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/l10n.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _dotColor = Color(0xFF38BDF8);

enum _Phase { show, ask }

/// Noktalar kısa süre görünür, sonra kaç tane olduğunu seçersin.
class DotCountScreen extends StatefulWidget {
  const DotCountScreen({super.key});

  @override
  State<DotCountScreen> createState() => _DotCountScreenState();
}

class _DotCountScreenState extends State<DotCountScreen> {
  static const String _id = 'dot_count';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<Offset> _dots = [];
  List<int> _options = [];
  _Phase _phase = _Phase.show;
  int? _missed;
  int _roundId = 0;
  int _hits = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;
  int get _target => math.min(3 + _hits ~/ 2, 18);
  int get _showMs => 700 + _target * 60;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _newRound() {
    _timer?.cancel();
    final pts = <Offset>[];
    var attempts = 0;
    while (pts.length < _target && attempts < 3000) {
      attempts++;
      final p = Offset(
        0.08 + _rnd.nextDouble() * 0.84,
        0.08 + _rnd.nextDouble() * 0.84,
      );
      final minD = attempts > 1000 ? 0.10 : 0.17;
      if (pts.every((q) => (q - p).distance >= minD)) pts.add(p);
    }
    final count = pts.length;

    final opts = <int>{count};
    final offs = List<int>.of(const [-3, -2, -1, 1, 2, 3, 4])..shuffle(_rnd);
    for (final o in offs) {
      if (opts.length >= 4) break;
      if (count + o >= 1) opts.add(count + o);
    }
    var extra = 5;
    while (opts.length < 4) {
      opts.add(count + extra++);
    }

    setState(() {
      _dots = pts;
      _options = opts.toList()..shuffle(_rnd);
      _phase = _Phase.show;
      _roundId++;
    });
    _timer = Timer(Duration(milliseconds: _showMs), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.ask);
    });
  }

  void _start() {
    _timer?.cancel();
    _hits = 0;
    _lives = _maxLives;
    _missed = null;
    _over = false;
    _isNewBest = false;
    _newRound();
  }

  void _choose(int v) {
    if (_over || _phase != _Phase.ask) return;
    if (v == _dots.length) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      _hits++;
      _missed = null;
      _newRound();
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives--;
      _missed = _dots.length;
      if (_lives <= 0) {
        _finish();
      } else {
        _newRound();
      }
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

  Widget _board(AppStrings t) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = math.min(math.min(box.maxWidth, box.maxHeight), 320.0);
        final dotSize = side * 0.08;
        return SizedBox(
          width: side,
          height: side,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _phase == _Phase.show
                ? Stack(
                    children: [
                      for (final p in _dots)
                        Positioned(
                          left: p.dx * side - dotSize / 2,
                          top: p.dy * side - dotSize / 2,
                          child: Container(
                            width: dotSize,
                            height: dotSize,
                            decoration: const BoxDecoration(
                              color: _dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  )
                : const Center(
                    child: Icon(Icons.question_mark_rounded, size: 64, color: AppColors.textDim),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final asking = _phase == _Phase.ask;
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Correct answers: $_hits', 'Doğru cevap: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Round ${_hits + 1}', 'Tur ${_hits + 1}'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 28,
                            child: Center(
                              child: Text(
                                asking
                                    ? t.p('How many dots?', 'Kaç nokta vardı?')
                                    : (_missed != null
                                        ? t.p('Last answer was $_missed', 'Önceki cevap $_missed idi')
                                        : t.p('Look carefully', 'Dikkatle bak')),
                                style: TextStyle(
                                  color: !asking && _missed != null
                                      ? AppColors.bad
                                      : AppColors.textDim,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: Center(child: _board(t))),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 8,
                            width: 200,
                            child: asking
                                ? null
                                : TweenAnimationBuilder<double>(
                                    key: ValueKey<int>(_roundId),
                                    tween: Tween<double>(begin: 1, end: 0),
                                    duration: Duration(milliseconds: _showMs),
                                    builder: (context, v, _) => LinearProgressIndicator(
                                      value: v,
                                      minHeight: 6,
                                      borderRadius: BorderRadius.circular(3),
                                      color: _dotColor,
                                      backgroundColor: AppColors.surface,
                                    ),
                                  ),
                          ),
                        ],
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
                                        height: 60,
                                        child: FilledButton.tonal(
                                          onPressed: asking
                                              ? () => _choose(_options[row * 2 + col])
                                              : null,
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: Text(
                                            '${_options[row * 2 + col]}',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
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
