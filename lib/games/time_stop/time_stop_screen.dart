import 'dart:async';
import 'dart:math' as math;

import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _timeColor = Color(0xFFC4B5FD);

enum _Phase { ready, running, result }

/// Saat başlar, bir süre sonra görünmez olur. Hedef saniyede tam durdurmaya çalış.
class TimeStopScreen extends StatefulWidget {
  const TimeStopScreen({super.key});

  @override
  State<TimeStopScreen> createState() => _TimeStopScreenState();
}

class _TimeStopScreenState extends State<TimeStopScreen> {
  static const String _id = 'time_stop';
  static const int _rounds = 5;

  final math.Random _rnd = math.Random();
  final Stopwatch _sw = Stopwatch();
  Timer? _tick;

  List<int> _targets = [];
  _Phase _phase = _Phase.ready;
  int _round = 1;
  int _score = 0;
  int _elapsedMs = 0;
  int _lastPoints = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _target => _targets[_round - 1];

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _reset() {
    _tick?.cancel();
    _sw
      ..stop()
      ..reset();
    _targets = ([3, 4, 5, 6, 7, 8]..shuffle(_rnd)).sublist(0, _rounds);
    _round = 1;
    _score = 0;
    _elapsedMs = 0;
    _phase = _Phase.ready;
    _over = false;
    _isNewBest = false;
  }

  void _start() => setState(_reset);

  void _run() {
    _sw
      ..reset()
      ..start();
    setState(() {
      _elapsedMs = 0;
      _phase = _Phase.running;
    });
    _tick = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs = _sw.elapsedMilliseconds);
    });
  }

  void _stop() {
    _sw.stop();
    _tick?.cancel();
    final elapsed = _sw.elapsedMilliseconds;
    final diff = (elapsed - _target * 1000).abs();
    final points = math.max(0, 100 - (diff / 10).round());
    if (diff < 300) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    setState(() {
      _elapsedMs = elapsed;
      _lastPoints = points;
      _score += points;
      _phase = _Phase.result;
    });
  }

  void _next() {
    if (_round >= _rounds) {
      _finish();
    } else {
      setState(() {
        _round++;
        _elapsedMs = 0;
        _phase = _Phase.ready;
      });
    }
  }

  Future<void> _finish() async {
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
    final targetMs = _targets.isEmpty ? 0 : _target * 1000;
    final showClock = _phase == _Phase.running && _elapsedMs < targetMs * 0.4;
    final signed = (_elapsedMs - targetMs) / 1000;

    String big;
    if (_phase == _Phase.ready) {
      big = '0.00';
    } else if (_phase == _Phase.running) {
      big = showClock ? (_elapsedMs / 1000).toStringAsFixed(2) : '?.??';
    } else {
      big = (_elapsedMs / 1000).toStringAsFixed(2);
    }

    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
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
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p('Stop the clock at', 'Saati şurada durdur'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              t.p('$_target seconds', '$_target saniye'),
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: _timeColor,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: Text(
                                big,
                                style: const TextStyle(
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 48,
                              child: _phase == _Phase.result
                                  ? Column(
                                      children: [
                                        Text(
                                          '${signed >= 0 ? '+' : ''}${signed.toStringAsFixed(2)} s',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: signed.abs() < 0.3
                                                ? AppColors.good
                                                : AppColors.bad,
                                          ),
                                        ),
                                        Text(
                                          '+$_lastPoints ${t.points}',
                                          style: const TextStyle(
                                            color: AppColors.textDim,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _phase == _Phase.ready
                        ? PillButton(
                            label: t.p('Start', 'Başlat'),
                            color: _timeColor,
                            textColor: Colors.black,
                            onPressed: _run,
                          )
                        : _phase == _Phase.running
                            ? PillButton(
                                label: t.p('Stop', 'Durdur'),
                                color: AppColors.accent,
                                onPressed: _stop,
                              )
                            : PillButton(
                                label: t.p('Next', 'Sonraki'),
                                color: _timeColor,
                                textColor: Colors.black,
                                onPressed: _next,
                              ),
                  ),
                ],
              ),
      ),
    );
  }
}
