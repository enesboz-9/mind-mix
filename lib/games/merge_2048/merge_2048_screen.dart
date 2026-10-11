import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// 2048: kaydırarak aynı sayıları birleştir.
class Merge2048Screen extends StatefulWidget {
  const Merge2048Screen({super.key});

  @override
  State<Merge2048Screen> createState() => _Merge2048ScreenState();
}

class _Merge2048ScreenState extends State<Merge2048Screen> {
  static const String _id = 'merge_2048';
  static const int _n = 4;

  final math.Random _rnd = math.Random();

  List<List<int>> _board = [];
  int _score = 0;
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
    // Oyundan yarıda çıkılsa da skor kaybolmasın.
    if (!_over && _score > 0) ScoreStore.submit(_id, _score);
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _board = List.generate(_n, (_) => List<int>.filled(_n, 0));
      _score = 0;
      _over = false;
      _isNewBest = false;
      _spawn();
      _spawn();
    });
  }

  void _spawn() {
    final empty = <int>[];
    for (var r = 0; r < _n; r++) {
      for (var c = 0; c < _n; c++) {
        if (_board[r][c] == 0) empty.add(r * _n + c);
      }
    }
    if (empty.isEmpty) return;
    final i = empty[_rnd.nextInt(empty.length)];
    _board[i ~/ _n][i % _n] = _rnd.nextDouble() < 0.9 ? 2 : 4;
  }

  /// Bir satırı sola kaydırır; (yeni satır, kazanılan puan) döndürür.
  (List<int>, int) _slide(List<int> line) {
    final nz = line.where((v) => v != 0).toList();
    final out = <int>[];
    var gained = 0;
    for (var i = 0; i < nz.length; i++) {
      if (i + 1 < nz.length && nz[i] == nz[i + 1]) {
        out.add(nz[i] * 2);
        gained += nz[i] * 2;
        i++;
      } else {
        out.add(nz[i]);
      }
    }
    while (out.length < _n) {
      out.add(0);
    }
    return (out, gained);
  }

  /// dir: 0 sol, 1 sağ, 2 yukarı, 3 aşağı. Tahtayı değiştirdiyse true.
  bool _apply(List<List<int>> b, int dir, {required void Function(int) onGain}) {
    var changed = false;
    for (var i = 0; i < _n; i++) {
      final line = <int>[];
      for (var j = 0; j < _n; j++) {
        final r = dir < 2 ? i : j;
        final c = dir < 2 ? j : i;
        line.add(b[r][c]);
      }
      final reversed = dir == 1 || dir == 3;
      final src = reversed ? line.reversed.toList() : line;
      final (res, gained) = _slide(src);
      final dst = reversed ? res.reversed.toList() : res;
      onGain(gained);
      for (var j = 0; j < _n; j++) {
        final r = dir < 2 ? i : j;
        final c = dir < 2 ? j : i;
        if (b[r][c] != dst[j]) {
          changed = true;
          b[r][c] = dst[j];
        }
      }
    }
    return changed;
  }

  bool _canMove() {
    for (var d = 0; d < 4; d++) {
      final copy = [for (final row in _board) List<int>.of(row)];
      if (_apply(copy, d, onGain: (_) {})) return true;
    }
    return false;
  }

  void _move(int dir) {
    if (_over) return;
    var gain = 0;
    final changed = _apply(_board, dir, onGain: (g) => gain += g);
    if (!changed) return;
    HapticFeedback.selectionClick();
    if (gain > 0) Sfx.correct();
    setState(() {
      _score += gain;
      _spawn();
    });
    if (!_canMove()) _finish();
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

  void _onPanEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    if (v.distance < 150) return;
    if (v.dx.abs() > v.dy.abs()) {
      _move(v.dx > 0 ? 1 : 0);
    } else {
      _move(v.dy > 0 ? 3 : 2);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _move(0);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _move(1);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _move(2);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _move(3);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Color _tileColor(int v) {
    if (v == 0) return const Color(0xFF262A3A);
    final i = (math.log(v) / math.ln2).round();
    return HSLColor.fromAHSL(1, (i * 32.0 + 330) % 360, 0.65, 0.55).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    var top = 0;
    for (final row in _board) {
      for (final v in row) {
        top = math.max(top, v);
      }
    }
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Top tile: $top', 'En büyük kare: $top'),
                onAgain: _start,
                onMenu: _close,
              )
            : Focus(
                autofocus: true,
                onKeyEvent: _onKey,
                child: Column(
                  children: [
                    GameHud(
                      label: t.p('Top tile $top', 'En büyük $top'),
                      score: _score,
                      onClose: _close,
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanEnd: _onPanEnd,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    for (var r = 0; r < _n; r++)
                                      Expanded(
                                        child: Row(
                                          children: [
                                            for (var c = 0; c < _n; c++)
                                              Expanded(child: _tile(_board[r][c])),
                                          ],
                                        ),
                                      ),
                                  ],
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
      ),
    );
  }

  Widget _tile(int v) {
    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _tileColor(v),
        borderRadius: BorderRadius.circular(10),
      ),
      child: v == 0
          ? null
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  '$v',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
    );
  }
}
