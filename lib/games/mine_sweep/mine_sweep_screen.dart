import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

class _Cell {
  bool mine = false;
  bool open = false;
  bool flag = false;
  int near = 0;
}

/// 6x6 mayın tarlası. İlk dokunuş her zaman güvenlidir. Tahtadaki tüm güvenli
/// kareleri aç, bir sonraki tahtada mayın sayısı artar. Mayına basarsan oyun biter.
/// Uzun basış (ya da alttaki "Bayrak" modu) bayrak koyar.
class MineSweepScreen extends StatefulWidget {
  const MineSweepScreen({super.key});

  @override
  State<MineSweepScreen> createState() => _MineSweepScreenState();
}

class _MineSweepScreenState extends State<MineSweepScreen> {
  static const String _id = 'mine_sweep';
  static const int _size = 6;
  static const List<Color> _numColors = [
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFF5E7E),
    Color(0xFFA472EE),
    Color(0xFFFFC94D),
    Color(0xFF22D3EE),
    Color(0xFFFF8A4D),
    Color(0xFFE879F9),
  ];

  final math.Random _rnd = math.Random();

  List<_Cell> _cells = [];
  int _level = 1;
  int _score = 0;
  int _best = 0;
  bool _flagMode = false;
  bool _placed = false;
  bool _locked = false;
  bool _boom = false;
  bool _cleared = false;
  bool _over = false;
  bool _isNewBest = false;

  int get _mines => math.min(4 + _level, 12);

  @override
  void initState() {
    super.initState();
    _newBoard();
  }

  void _close() => Navigator.of(context).pop();

  void _newBoard() {
    _cells = List<_Cell>.generate(_size * _size, (_) => _Cell());
    _placed = false;
    _locked = false;
    _boom = false;
    _cleared = false;
  }

  void _start() {
    setState(() {
      _level = 1;
      _score = 0;
      _flagMode = false;
      _over = false;
      _isNewBest = false;
      _newBoard();
    });
  }

  Iterable<int> _neighbors(int i) sync* {
    final r = i ~/ _size;
    final c = i % _size;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final rr = r + dr;
        final cc = c + dc;
        if (rr < 0 || cc < 0 || rr >= _size || cc >= _size) continue;
        yield rr * _size + cc;
      }
    }
  }

  /// Mayınlar ilk dokunuştan sonra yerleşir; dokunulan kare ve komşuları temiz kalır.
  void _placeMines(int safe) {
    final banned = <int>{safe, ..._neighbors(safe)};
    final spots = <int>[
      for (var i = 0; i < _cells.length; i++)
        if (!banned.contains(i)) i,
    ]..shuffle(_rnd);
    for (final i in spots.take(_mines)) {
      _cells[i].mine = true;
    }
    for (var i = 0; i < _cells.length; i++) {
      _cells[i].near = _neighbors(i).where((n) => _cells[n].mine).length;
    }
    _placed = true;
  }

  void _flood(int start) {
    final stack = <int>[start];
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      final c = _cells[i];
      if (c.open || c.mine) continue;
      c.open = true;
      c.flag = false;
      if (c.near == 0) stack.addAll(_neighbors(i));
    }
  }

  int get _openCount => _cells.where((c) => c.open).length;

  void _toggleFlag(int i) {
    if (_locked) return;
    final c = _cells[i];
    if (c.open) return;
    HapticFeedback.mediumImpact();
    setState(() => c.flag = !c.flag);
  }

  void _tap(int i) {
    if (_locked) return;
    final c = _cells[i];
    if (c.open) return;
    if (_flagMode) {
      _toggleFlag(i);
      return;
    }
    if (c.flag) return;
    if (!_placed) _placeMines(i);
    HapticFeedback.selectionClick();
    if (c.mine) {
      _explode();
      return;
    }
    setState(() => _flood(i));
    if (_openCount == _cells.length - _mines) _clear();
  }

  Future<void> _explode() async {
    _locked = true;
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    setState(() {
      _boom = true;
      for (final c in _cells) {
        if (c.mine) c.open = true;
      }
    });
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    await _finish();
  }

  Future<void> _clear() async {
    _locked = true;
    Sfx.correct();
    setState(() {
      _cleared = true;
      _score++;
    });
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _level++;
      _newBoard();
    });
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

  Widget _buildCell(int i) {
    final c = _cells[i];
    Color bg;
    Widget? child;
    if (c.open) {
      if (c.mine) {
        bg = AppColors.bad.withAlpha(150);
        child = const Text('💣', style: TextStyle(fontSize: 22));
      } else {
        bg = const Color(0xFF181B26);
        if (c.near > 0) {
          child = Text(
            '${c.near}',
            style: TextStyle(
              color: _numColors[c.near - 1],
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          );
        }
      }
    } else {
      bg = const Color(0xFF2E3348);
      if (c.flag) child = const Text('🚩', style: TextStyle(fontSize: 20));
    }
    return GestureDetector(
      onTap: () => _tap(i),
      onLongPress: () => _toggleFlag(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    if (_over) {
      return Scaffold(
        body: SafeArea(
          child: GameOverPanel(
            score: _score,
            best: _best,
            isNewBest: _isNewBest,
            onAgain: _start,
            onMenu: _close,
          ),
        ),
      );
    }
    final flags = _cells.where((c) => c.flag).length;
    final String status;
    final Color statusColor;
    if (_boom) {
      status = t.p('Boom!', 'Patladı!');
      statusColor = AppColors.bad;
    } else if (_cleared) {
      status = t.p('Board cleared!', 'Tahta temiz!');
      statusColor = AppColors.good;
    } else {
      status = t.p('Open every safe square', 'Tüm güvenli kareleri aç');
      statusColor = Colors.white;
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GameHud(label: t.level(_level), score: _score, onClose: _close),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ),
            Text(
              '💣 ${math.max(0, _mines - flags)}',
              style: const TextStyle(color: AppColors.textDim, fontSize: 15),
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
                          crossAxisCount: _size,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          physics: const NeverScrollableScrollPhysics(),
                          children: List<Widget>.generate(_size * _size, _buildCell),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.touch_app_rounded),
                    label: Text(t.p('Reveal', 'Aç')),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.flag_rounded),
                    label: Text(t.p('Flag', 'Bayrak')),
                  ),
                ],
                selected: {_flagMode},
                onSelectionChanged: (s) => setState(() => _flagMode = s.first),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
