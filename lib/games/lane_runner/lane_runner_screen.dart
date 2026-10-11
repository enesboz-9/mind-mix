import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Row {
  _Row(this.blocked) : y = -60;

  final Set<int> blocked;
  double y;
  bool counted = false;
}

/// 3 şeritli yol: ekranın sol / sağ yarısına dokunarak şerit değiştir, engellere çarpma.
class LaneRunnerScreen extends StatefulWidget {
  const LaneRunnerScreen({super.key});

  @override
  State<LaneRunnerScreen> createState() => _LaneRunnerScreenState();
}

class _LaneRunnerScreenState extends State<LaneRunnerScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'lane_runner';
  static const double _rowH = 50;
  static const double _carH = 56;
  static const double _carBottom = 40;

  final math.Random _rnd = math.Random();
  late final GameLoop _loop;

  final List<_Row> _rows = [];
  double _w = 0;
  double _h = 0;
  int _lane = 1;
  int _passed = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _passed * 10;

  @override
  void initState() {
    super.initState();
    _loop = GameLoop(this, _tick);
    _start();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _rows.clear();
      _lane = 1;
      _passed = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _go(int dir) {
    if (_over) return;
    setState(() => _lane = (_lane + dir).clamp(0, 2).toInt());
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _tick(double dt) {
    if (_over || _w <= 0 || _h <= 0) return;
    final speed = math.min(620.0, 260.0 + _passed * 6.0);
    final gap = math.max(170.0, 250.0 - _passed * 2.0);
    if (_rows.isEmpty || _rows.last.y > gap) {
      final blocked = <int>{_rnd.nextInt(3)};
      if (_passed >= 5 && _rnd.nextDouble() < 0.45) {
        blocked.add(_rnd.nextInt(3));
      }
      if (blocked.length >= 3) blocked.remove(blocked.first);
      _rows.add(_Row(blocked));
    }
    final carTop = _h - _carBottom - _carH;
    for (final r in _rows) {
      r.y += speed * dt;
      final overlaps = r.y + _rowH > carTop + 6 && r.y < carTop + _carH - 6;
      if (overlaps && r.blocked.contains(_lane)) {
        _finish();
        return;
      }
      if (!r.counted && r.y > carTop + _carH) {
        r.counted = true;
        _passed++;
        Sfx.correct();
      }
    }
    _rows.removeWhere((r) => r.y > _h + 10);
    setState(() {});
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
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
                extra: t.p('Obstacles passed: $_passed', 'Geçilen engel: $_passed'),
                onAgain: _start,
                onMenu: _close,
              )
            : Focus(
                autofocus: true,
                onKeyEvent: _onKey,
                child: Column(
                  children: [
                    GameHud(
                      label: t.p('Passed $_passed', 'Geçilen $_passed'),
                      score: _score,
                      onClose: _close,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: LayoutBuilder(
                            builder: (context, box) {
                              _w = box.maxWidth;
                              _h = box.maxHeight;
                              final laneW = _w / 3;
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (d) => _go(d.localPosition.dx < _w / 2 ? -1 : 1),
                                child: ClipRect(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: Container(color: AppColors.surface),
                                      ),
                                      for (var i = 1; i < 3; i++)
                                        Positioned(
                                          left: laneW * i - 1,
                                          top: 0,
                                          bottom: 0,
                                          child: Container(width: 2, color: Colors.white12),
                                        ),
                                      for (final r in _rows)
                                        for (final l in r.blocked)
                                          Positioned(
                                            left: laneW * l + 8,
                                            top: r.y,
                                            child: Container(
                                              width: laneW - 16,
                                              height: _rowH,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFC94D),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                      AnimatedPositioned(
                                        duration: const Duration(milliseconds: 90),
                                        left: laneW * _lane + laneW * 0.2,
                                        top: _h - _carBottom - _carH,
                                        child: Container(
                                          width: laneW * 0.6,
                                          height: _carH,
                                          decoration: BoxDecoration(
                                            color: AppColors.accent,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
