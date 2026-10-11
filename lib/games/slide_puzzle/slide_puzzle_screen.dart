import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _slideColor = Color(0xFF93C5FD);

/// 3x3 kaydırmalı bulmaca: kareleri 1'den 8'e sıraya diz. 120 saniyede
/// kaç tahta çözebilirsin? Her tahta 100 puan.
class SlidePuzzleScreen extends StatefulWidget {
  const SlidePuzzleScreen({super.key});

  @override
  State<SlidePuzzleScreen> createState() => _SlidePuzzleScreenState();
}

class _SlidePuzzleScreenState extends State<SlidePuzzleScreen> {
  static const String _id = 'slide_puzzle';
  static const int _totalSeconds = 120;

  final math.Random _rnd = math.Random();
  Timer? _ticker;
  Timer? _flashTimer;

  List<int> _board = [];
  int _moves = 0;
  int _solved = 0;
  int _secs = _totalSeconds;
  int _best = 0;
  bool _flash = false;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _solved * 100;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _flashTimer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  bool _isSolved(List<int> b) {
    for (var i = 0; i < 8; i++) {
      if (b[i] != i + 1) return false;
    }
    return b[8] == 0;
  }

  List<int> _neighbors(int idx) {
    final r = idx ~/ 3;
    final c = idx % 3;
    return [
      if (r > 0) idx - 3,
      if (r < 2) idx + 3,
      if (c > 0) idx - 1,
      if (c < 2) idx + 1,
    ];
  }

  /// Çözülmüş tahtadan rastgele geçerli hamlelerle karıştırır; her zaman çözülebilir.
  void _newBoard() {
    do {
      final b = <int>[1, 2, 3, 4, 5, 6, 7, 8, 0];
      var blank = 8;
      var prev = -1;
      final n = math.min(60, 20 + _solved * 5);
      for (var i = 0; i < n; i++) {
        final opts = _neighbors(blank).where((x) => x != prev).toList();
        final pick = opts[_rnd.nextInt(opts.length)];
        b[blank] = b[pick];
        b[pick] = 0;
        prev = blank;
        blank = pick;
      }
      _board = b;
    } while (_isSolved(_board));
    _moves = 0;
    _flash = false;
  }

  void _start() {
    _ticker?.cancel();
    _flashTimer?.cancel();
    setState(() {
      _secs = _totalSeconds;
      _solved = 0;
      _over = false;
      _isNewBest = false;
      _newBoard();
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _secs--);
      if (_secs <= 0) _finish();
    });
  }

  void _tapTile(int v) {
    if (_flash || _over) return;
    final idx = _board.indexOf(v);
    final blank = _board.indexOf(0);
    if (!_neighbors(idx).contains(blank)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _board[blank] = v;
      _board[idx] = 0;
      _moves++;
    });
    if (_isSolved(_board)) {
      Sfx.correct();
      setState(() {
        _solved++;
        _flash = true;
      });
      _flashTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted || _over) return;
        setState(_newBoard);
      });
    }
  }

  Future<void> _finish() async {
    if (_over) return;
    _ticker?.cancel();
    _flashTimer?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _boardView(double side) {
    const gap = 8.0;
    final cell = (side - gap * 2) / 3;
    final color = _flash ? AppColors.good : _slideColor;
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        children: [
          for (var v = 1; v <= 8; v++)
            AnimatedPositioned(
              key: ValueKey<int>(v),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
              left: (_board.indexOf(v) % 3) * (cell + gap),
              top: (_board.indexOf(v) ~/ 3) * (cell + gap),
              width: cell,
              height: cell,
              child: GestureDetector(
                onTap: () => _tapTile(v),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withAlpha(50),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withAlpha(160), width: 2),
                  ),
                  child: Text(
                    '$v',
                    style: TextStyle(
                      fontSize: cell * 0.42,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
                    label: t.p('Moves $_moves', 'Hamle $_moves'),
                    score: _score,
                    timeText: '${_secs}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _flash
                          ? t.p('Solved! +100', 'Çözüldü! +100')
                          : t.p('Put the tiles in order 1-8', 'Kareleri 1-8 sıraya diz'),
                      style: TextStyle(
                        color: _flash ? AppColors.good : AppColors.textDim,
                        fontSize: 15,
                        fontWeight: _flash ? FontWeight.w800 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final side = math.min(math.min(box.maxWidth, box.maxHeight), 340.0);
                          return Center(child: _boardView(side));
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
