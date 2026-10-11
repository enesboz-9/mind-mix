import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// 4x4 Mini Sudoku: her satır, sütun ve 2x2 kutuda 1-4 birer kez. 3 can.
class MiniSudokuScreen extends StatefulWidget {
  const MiniSudokuScreen({super.key});

  @override
  State<MiniSudokuScreen> createState() => _MiniSudokuScreenState();
}

class _MiniSudokuScreenState extends State<MiniSudokuScreen> {
  static const String _id = 'mini_sudoku';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();

  List<List<int>> _solution = [];
  List<List<int>> _grid = [];
  List<List<bool>> _given = [];
  int _selR = -1;
  int _selC = -1;
  int _lives = _maxLives;
  int _solved = 0;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _lives = _maxLives;
      _solved = 0;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _newPuzzle();
    });
  }

  bool _ok(List<List<int>> g, int r, int c, int v) {
    for (var i = 0; i < 4; i++) {
      if (g[r][i] == v || g[i][c] == v) return false;
    }
    final br = r ~/ 2 * 2;
    final bc = c ~/ 2 * 2;
    for (var i = 0; i < 2; i++) {
      for (var j = 0; j < 2; j++) {
        if (g[br + i][bc + j] == v) return false;
      }
    }
    return true;
  }

  /// Çözüm sayısını (en fazla 2'ye kadar) sayar.
  int _count(List<List<int>> g) {
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        if (g[r][c] != 0) continue;
        var total = 0;
        for (var v = 1; v <= 4; v++) {
          if (_ok(g, r, c, v)) {
            g[r][c] = v;
            total += _count(g);
            g[r][c] = 0;
            if (total >= 2) return total;
          }
        }
        return total;
      }
    }
    return 1;
  }

  List<List<int>> _makeSolution() {
    // Temel desen + geçerliliği bozmayan karıştırmalar.
    final digits = [1, 2, 3, 4]..shuffle(_rnd);
    final rowOrder = <int>[
      ...([0, 1]..shuffle(_rnd)),
      ...([2, 3]..shuffle(_rnd)),
    ];
    final bandSwap = _rnd.nextBool();
    final colOrder = <int>[
      ...([0, 1]..shuffle(_rnd)),
      ...([2, 3]..shuffle(_rnd)),
    ];
    final stackSwap = _rnd.nextBool();
    int base(int r, int c) => (2 * (r % 2) + r ~/ 2 + c) % 4;
    return List.generate(4, (r) {
      var rr = rowOrder[r];
      if (bandSwap) rr = (rr + 2) % 4;
      return List.generate(4, (c) {
        var cc = colOrder[c];
        if (stackSwap) cc = (cc + 2) % 4;
        return digits[base(rr, cc)];
      });
    });
  }

  void _newPuzzle() {
    _solution = _makeSolution();
    final g = [for (final row in _solution) List<int>.of(row)];
    final cells = List<int>.generate(16, (i) => i)..shuffle(_rnd);
    final target = math.min(11, 7 + _solved);
    var removed = 0;
    for (final i in cells) {
      if (removed >= target) break;
      final r = i ~/ 4;
      final c = i % 4;
      final keep = g[r][c];
      g[r][c] = 0;
      final copy = [for (final row in g) List<int>.of(row)];
      if (_count(copy) == 1) {
        removed++;
      } else {
        g[r][c] = keep;
      }
    }
    _grid = g;
    _given = [
      for (var r = 0; r < 4; r++) [for (var c = 0; c < 4; c++) g[r][c] != 0],
    ];
    _selR = -1;
    _selC = -1;
  }

  void _selectCell(int r, int c) {
    if (_over || _given[r][c] || _grid[r][c] != 0) return;
    setState(() {
      _selR = r;
      _selC = c;
    });
  }

  void _place(int v) {
    if (_over || _selR < 0) return;
    if (_solution[_selR][_selC] == v) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _grid[_selR][_selC] = v;
        _selR = -1;
        _selC = -1;
      });
      if (_grid.every((row) => row.every((x) => x != 0))) {
        setState(() {
          _score += 20 + _solved * 2;
          _solved++;
          _newPuzzle();
        });
      }
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _lives--;
      if (_lives <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _finish() async {
    setState(() {
      _lives = 0;
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
                extra: t.p('Puzzles solved: $_solved', 'Çözülen bulmaca: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Solved $_solved', 'Çözülen $_solved'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      t.p('Pick a cell, then a number', 'Bir kare, sonra bir sayı seç'),
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
                              child: Column(
                                children: [
                                  for (var r = 0; r < 4; r++)
                                    Expanded(
                                      child: Row(
                                        children: [
                                          for (var c = 0; c < 4; c++)
                                            Expanded(child: _cell(r, c)),
                                        ],
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                    child: Row(
                      children: [
                        for (var v = 1; v <= 4; v++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              child: SizedBox(
                                height: 60,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  onPressed: _selR < 0 ? null : () => _place(v),
                                  child: Text(
                                    '$v',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _cell(int r, int c) {
    final selected = r == _selR && c == _selC;
    final v = _grid[r][c];
    final given = _given[r][c];
    // 2x2 kutuları ayırmak için ortadaki boşluk biraz daha geniş.
    final margin = EdgeInsets.fromLTRB(
      c == 2 ? 6 : 2,
      r == 2 ? 6 : 2,
      c == 1 ? 6 : 2,
      r == 1 ? 6 : 2,
    );
    return GestureDetector(
      onTap: () => _selectCell(r, c),
      child: Container(
        margin: margin,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withAlpha(120) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: selected ? Border.all(color: AppColors.accent, width: 2) : null,
        ),
        child: Text(
          v == 0 ? '' : '$v',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: given ? Colors.white : const Color(0xFF7DD3FC),
          ),
        ),
      ),
    );
  }
}
