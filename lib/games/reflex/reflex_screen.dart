import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

enum _Phase { wait, go, result, early }

/// Ekran yeşile dönünce olabildiğince hızlı dokun. 5 tur; erken dokunursan o tur 0 puan.
class ReflexScreen extends StatefulWidget {
  const ReflexScreen({super.key});

  @override
  State<ReflexScreen> createState() => _ReflexScreenState();
}

class _ReflexScreenState extends State<ReflexScreen> {
  static const String _id = 'reflex';
  static const int _rounds = 5;

  final math.Random _rnd = math.Random();
  final List<int> _times = [];
  Timer? _timer;
  DateTime? _goAt;

  _Phase _phase = _Phase.wait;
  int _round = 1;
  int _score = 0;
  int _lastMs = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _begin();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _begin() {
    _timer?.cancel();
    setState(() => _phase = _Phase.wait);
    _timer = Timer(Duration(milliseconds: 1200 + _rnd.nextInt(2500)), () {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.go;
        _goAt = DateTime.now();
      });
    });
  }

  void _start() {
    _timer?.cancel();
    _times.clear();
    _round = 1;
    _score = 0;
    _over = false;
    _isNewBest = false;
    _begin();
  }

  void _advance(int delayMs) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted) return;
      if (_round >= _rounds) {
        _finish();
      } else {
        _round++;
        _begin();
      }
    });
  }

  void _tap() {
    if (_phase == _Phase.wait) {
      _timer?.cancel();
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() => _phase = _Phase.early);
      _advance(1200);
    } else if (_phase == _Phase.go) {
      final ms = DateTime.now().difference(_goAt ?? DateTime.now()).inMilliseconds;
      HapticFeedback.selectionClick();
      Sfx.correct();
      _times.add(ms);
      setState(() {
        _lastMs = ms;
        _score += math.max(0, 500 - ms);
        _phase = _Phase.result;
      });
      _advance(1300);
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

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final String text;
    final Color color;
    switch (_phase) {
      case _Phase.wait:
        text = t.p('Wait for green…', 'Yeşili bekle…');
        color = const Color(0xFFDC2626);
        break;
      case _Phase.go:
        text = t.p('TAP!', 'DOKUN!');
        color = const Color(0xFF16A34A);
        break;
      case _Phase.result:
        text = '$_lastMs ms';
        color = const Color(0xFF2563EB);
        break;
      case _Phase.early:
        text = t.p('Too soon!', 'Çok erken!');
        color = const Color(0xFFD97706);
        break;
    }
    final avg = _times.isEmpty
        ? '-'
        : '${(_times.reduce((a, b) => a + b) / _times.length).round()} ms';

    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Average: $avg', 'Ortalama: $avg'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Round $_round/$_rounds', 'Tur $_round/$_rounds'),
                    score: _score,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _tap(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
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
