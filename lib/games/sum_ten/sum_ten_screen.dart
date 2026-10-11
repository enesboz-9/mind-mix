import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Toplamı 10 eden iki sayıya dokun. 40 saniye, yanlış eşleşme 2 saniye götürür.
class SumTenScreen extends StatefulWidget {
  const SumTenScreen({super.key});

  @override
  State<SumTenScreen> createState() => _SumTenScreenState();
}

class _SumTenScreenState extends State<SumTenScreen> {
  static const String _id = 'sum_ten';
  static const int _totalMs = 40000;
  static const int _penaltyMs = 2000;
  static const int _cols = 4;
  static const int _count = 16;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<int> _cells = [];
  int _sel = -1;
  int _pairs = 0;
  int _score = 0;
  int _timeMs = _totalMs;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    _timer?.cancel();
    setState(() {
      _cells = List<int>.generate(_count, (_) => 1 + _rnd.nextInt(9));
      _ensurePair();
      _sel = -1;
      _pairs = 0;
      _score = 0;
      _timeMs = _totalMs;
      _over = false;
      _isNewBest = false;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _timeMs -= 100;
      if (_timeMs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  bool _hasPair() {
    for (var i = 0; i < _count; i++) {
      for (var j = i + 1; j < _count; j++) {
        if (_cells[i] + _cells[j] == 10) return true;
      }
    }
    return false;
  }

  /// Tahtada her zaman en az bir çözüm olsun.
  void _ensurePair() {
    if (_hasPair()) return;
    final a = _rnd.nextInt(_count);
    var b = _rnd.nextInt(_count);
    if (b == a) b = (a + 1) % _count;
    _cells[b] = 10 - _cells[a];
  }

  void _tap(int i) {
    if (_over) return;
    if (_sel == -1) {
      setState(() => _sel = i);
      return;
    }
    if (_sel == i) {
      setState(() => _sel = -1);
      return;
    }
    if (_cells[_sel] + _cells[i] == 10) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _cells[_sel] = 1 + _rnd.nextInt(9);
        _cells[i] = 1 + _rnd.nextInt(9);
        _ensurePair();
        _sel = -1;
        _pairs++;
        _score += 10;
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _timeMs -= _penaltyMs;
      if (_timeMs <= 0) {
        _finish();
      } else {
        setState(() => _sel = -1);
      }
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timeMs = 0;
      _over = true;
    });
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
                extra: t.p('Pairs: $_pairs', 'Eşleşme: $_pairs'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Pairs $_pairs', 'Eşleşme $_pairs'),
                    score: _score,
                    timeText: '${(_timeMs / 1000).ceil()}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_timeMs / _totalMs).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      t.p('Find two numbers that make 10', 'Toplamı 10 olan iki sayıyı bul'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                                crossAxisCount: _cols,
                                mainAxisSpacing: 8,
                                crossAxisSpacing: 8,
                                physics: const NeverScrollableScrollPhysics(),
                                children: List.generate(_count, (i) {
                                  final selected = i == _sel;
                                  return GestureDetector(
                                    onTap: () => _tap(i),
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: selected ? AppColors.accent : AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        '${_cells[i]}',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                        ),
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
