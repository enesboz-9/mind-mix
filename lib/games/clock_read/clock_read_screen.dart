import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _clockColor = Color(0xFF7DD3FC);

class _Time {
  const _Time(this.h, this.m);

  final int h;
  final int m;

  String get label => '$h:${m.toString().padLeft(2, '0')}';
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.h, this.m);

  final int h;
  final int m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(c, r, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      c,
      r - 2,
      Paint()
        ..color = Colors.white24
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );

    final tick = Paint()
      ..color = Colors.white54
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30;
      final d = Offset(math.sin(a), -math.cos(a));
      final long = i % 5 == 0;
      tick.strokeWidth = long ? 3.0 : 1.5;
      canvas.drawLine(c + d * (r * (long ? 0.86 : 0.91)), c + d * (r * 0.95), tick);
    }

    for (var i = 1; i <= 12; i++) {
      final a = i * math.pi / 6;
      final d = Offset(math.sin(a), -math.cos(a));
      final tp = TextPainter(
        text: TextSpan(
          text: '$i',
          style: TextStyle(
            color: Colors.white,
            fontSize: r * 0.17,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + d * (r * 0.70);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }

    final hourA = ((h % 12) + m / 60) * math.pi / 6;
    final minA = m * math.pi / 30;
    canvas.drawLine(
      c,
      c + Offset(math.sin(hourA), -math.cos(hourA)) * (r * 0.45),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      c,
      c + Offset(math.sin(minA), -math.cos(minA)) * (r * 0.68),
      Paint()
        ..color = _clockColor
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, 7, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.h != h || old.m != m;
}

/// Analog saati oku, doğru saati seç. 45 saniye, 3 can.
class ClockReadScreen extends StatefulWidget {
  const ClockReadScreen({super.key});

  @override
  State<ClockReadScreen> createState() => _ClockReadScreenState();
}

class _ClockReadScreenState extends State<ClockReadScreen> {
  static const String _id = 'clock_read';
  static const int _maxLives = 3;
  static const int _totalSeconds = 45;

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  _Time _correct = const _Time(12, 0);
  List<_Time> _options = [];
  int _secs = _totalSeconds;
  int _lives = _maxLives;
  int _hits = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  bool _has(List<_Time> l, _Time t) => l.any((x) => x.label == t.label);

  /// Yeni soru hazırlar (setState çağırmaz).
  void _next() {
    final step = _hits < 4 ? 15 : 5;
    final h = 1 + _rnd.nextInt(12);
    final m = _rnd.nextInt(60 ~/ step) * step;
    _correct = _Time(h, m);

    final opts = <_Time>[_correct];
    final hourFromMinute = (m ~/ 5) % 12 == 0 ? 12 : (m ~/ 5) % 12;
    final candidates = <_Time>[
      _Time(h, (m + step * (1 + _rnd.nextInt(3))) % 60),
      _Time(h % 12 + 1, m),
      _Time((h + 10) % 12 + 1, m),
      _Time(hourFromMinute, (h % 12) * 5),
    ]..shuffle(_rnd);
    for (final c in candidates) {
      if (opts.length >= 4) break;
      if (!_has(opts, c)) opts.add(c);
    }
    while (opts.length < 4) {
      final c = _Time(1 + _rnd.nextInt(12), _rnd.nextInt(60 ~/ step) * step);
      if (!_has(opts, c)) opts.add(c);
    }
    _options = opts..shuffle(_rnd);
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
      _next();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _secs--);
      if (_secs <= 0) _finish();
    });
  }

  void _choose(_Time t) {
    if (_over) return;
    if (t.label == _correct.label) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        _next();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _next();
      });
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
                extra: t.p('Correct answers: $_hits', 'Doğru cevap: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Correct $_hits', 'Doğru $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_secs}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(math.min(box.maxWidth, box.maxHeight), 280.0);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: CustomPaint(painter: _ClockPainter(_correct.h, _correct.m)),
                            ),
                          );
                        },
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
                                          onPressed: () => _choose(_options[row * 2 + col]),
                                          style: FilledButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: Text(
                                            _options[row * 2 + col].label,
                                            style: const TextStyle(
                                              fontSize: 24,
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
