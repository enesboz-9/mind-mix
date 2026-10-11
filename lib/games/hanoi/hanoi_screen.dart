import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Hanoi Kuleleri: tüm diskleri sağdaki çubuğa taşı. Hamle hakkı sınırlı; bölümler büyür.
class HanoiScreen extends StatefulWidget {
  const HanoiScreen({super.key});

  @override
  State<HanoiScreen> createState() => _HanoiScreenState();
}

class _HanoiScreenState extends State<HanoiScreen> {
  static const String _id = 'hanoi';

  List<List<int>> _pegs = [];
  int _n = 3;
  int _moves = 0;
  int _sel = -1;
  int _score = 0;
  int _solved = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _optimal => (1 << _n) - 1;
  int get _limit => _optimal + _n * 3 + 4;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _n = 3;
      _score = 0;
      _solved = 0;
      _over = false;
      _isNewBest = false;
      _setupLevel();
    });
  }

  void _setupLevel() {
    _pegs = [
      [for (var s = _n; s >= 1; s--) s],
      <int>[],
      <int>[],
    ];
    _moves = 0;
    _sel = -1;
  }

  void _tapPeg(int p) {
    if (_over) return;
    if (_sel == -1) {
      if (_pegs[p].isNotEmpty) setState(() => _sel = p);
      return;
    }
    if (_sel == p) {
      setState(() => _sel = -1);
      return;
    }
    final disc = _pegs[_sel].last;
    if (_pegs[p].isNotEmpty && _pegs[p].last < disc) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() => _sel = -1);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _pegs[_sel].removeLast();
      _pegs[p].add(disc);
      _sel = -1;
      _moves++;
    });
    if (_pegs[2].length == _n) {
      Sfx.correct();
      setState(() {
        _score += _n * 10 + (_moves == _optimal ? 10 : 0);
        _solved++;
        _n = math.min(7, _n + 1);
        _setupLevel();
      });
    } else if (_moves >= _limit) {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Color _discColor(int size) =>
      HSLColor.fromAHSL(1, (size * 47.0 + 330) % 360, 0.7, 0.58).toColor();

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
                extra: t.p('Towers solved: $_solved', 'Çözülen kule: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('$_n discs', '$_n disk'),
                    score: _score,
                    timeText: '$_moves/$_limit',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      t.p('Move the tower to the right peg', 'Kuleyi sağdaki çubuğa taşı'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
                      child: Row(
                        children: [
                          for (var p = 0; p < 3; p++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _tapPeg(p),
                                child: LayoutBuilder(
                                  builder: (context, box) {
                                    final maxW = box.maxWidth - 8;
                                    final discH = math.min(30.0, box.maxHeight / (_n + 1));
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: p == _sel
                                            ? AppColors.accent.withAlpha(40)
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          Container(
                                            width: 6,
                                            color: Colors.white24,
                                          ),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              for (var i = _pegs[p].length - 1; i >= 0; i--)
                                                Container(
                                                  width: maxW * (0.28 + 0.72 * _pegs[p][i] / _n),
                                                  height: discH - 3,
                                                  margin: const EdgeInsets.only(bottom: 3),
                                                  decoration: BoxDecoration(
                                                    color: _discColor(_pegs[p][i]),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: (p == _sel && i == _pegs[p].length - 1)
                                                        ? Border.all(color: Colors.white, width: 2)
                                                        : null,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
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
