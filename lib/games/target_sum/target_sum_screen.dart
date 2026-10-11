import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _sumColor = Color(0xFFFCD34D);

/// Toplamı tam hedef sayıya eşitleyen kareleri seç. Hedefi aşarsan can gider.
/// 45 saniye, 3 can.
class TargetSumScreen extends StatefulWidget {
  const TargetSumScreen({super.key});

  @override
  State<TargetSumScreen> createState() => _TargetSumScreenState();
}

class _TargetSumScreenState extends State<TargetSumScreen> {
  static const String _id = 'target_sum';
  static const int _maxLives = 3;
  static const int _totalSeconds = 45;

  final math.Random _rnd = math.Random();
  Timer? _ticker;

  List<int> _tiles = [];
  Set<int> _selected = <int>{};
  int _target = 0;
  int _secs = _totalSeconds;
  int _lives = _maxLives;
  int _hits = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;
  int get _sum => _selected.fold<int>(0, (a, i) => a + _tiles[i]);

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

  /// Yeni tur hazırlar (setState çağırmaz). Hedef her zaman ulaşılabilir.
  void _deal() {
    final n = math.min(6 + _hits ~/ 4, 9);
    final maxV = math.min(9 + _hits ~/ 2, 20);
    final k = math.min(n, 2 + (_hits >= 4 ? 1 : 0) + (_hits >= 10 ? 1 : 0));
    _tiles = List<int>.generate(n, (_) => 1 + _rnd.nextInt(maxV));
    final order = List<int>.generate(n, (i) => i)..shuffle(_rnd);
    var target = 0;
    for (var j = 0; j < k; j++) {
      target += _tiles[order[j]];
    }
    _target = target;
    _selected = <int>{};
  }

  void _start() {
    _ticker?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
      _deal();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _secs--);
      if (_secs <= 0) _finish();
    });
  }

  void _toggle(int i) {
    if (_over) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(i)) _selected.remove(i);
    });
    final sum = _sum;
    if (sum == _target) {
      Sfx.correct();
      setState(() {
        _hits++;
        _deal();
      });
    } else if (sum > _target) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _deal();
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
                extra: t.p('Targets hit: $_hits', 'Tutturulan hedef: $_hits'),
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
                    timeText: '${_secs}s',
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
                              t.p('Make the tiles add up to', 'Karelerin toplamı şu olsun'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_target',
                              style: const TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w900,
                                color: _sumColor,
                              ),
                            ),
                            Text(
                              t.p('Selected: $_sum', 'Seçilen: $_sum'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < _tiles.length; i++)
                                  GestureDetector(
                                    onTap: () => _toggle(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      width: 76,
                                      height: 76,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: _selected.contains(i)
                                            ? _sumColor
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _sumColor.withAlpha(120),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        '${_tiles[i]}',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: _selected.contains(i)
                                              ? Colors.black
                                              : Colors.white,
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
