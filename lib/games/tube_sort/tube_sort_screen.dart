import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Tüplerdeki renkleri ayır: bir tüpe dokun, sonra hedef tüpe dokun. Üstteki aynı
/// renkli katmanlar, hedef boşsa ya da üstü aynı renkse ve yer varsa aktarılır.
/// Her tüp tek renkle dolunca bölüm biter; sonraki bölümde renk sayısı artar.
class TubeSortScreen extends StatefulWidget {
  const TubeSortScreen({super.key});

  @override
  State<TubeSortScreen> createState() => _TubeSortScreenState();
}

class _TubeSortScreenState extends State<TubeSortScreen> {
  static const String _id = 'tube_sort';
  static const int _cap = 4;
  static const List<Color> _colors = [
    Color(0xFFFF5E7E),
    Color(0xFFFFC94D),
    Color(0xFF3DDC84),
    Color(0xFF4D9DFF),
    Color(0xFFA472EE),
    Color(0xFFFF8A4D),
    Color(0xFF22D3EE),
  ];

  final math.Random _rnd = math.Random();
  final List<List<List<int>>> _history = [];

  List<List<int>> _tubes = [];
  List<List<int>> _initial = [];
  int _level = 1;
  int _solvedCount = 0;
  int _moves = 0;
  int? _sel;
  bool _locked = false;

  int get _colorCount => math.min(3 + (_level - 1) ~/ 2, _colors.length);

  @override
  void initState() {
    super.initState();
    _buildLevel();
  }

  void _close() => Navigator.of(context).pop();

  static bool _isSolved(List<List<int>> tubes) {
    return tubes.every(
      (t) => t.isEmpty || (t.length == _cap && t.every((c) => c == t.first)),
    );
  }

  List<List<int>> _copy(List<List<int>> src) => [for (final t in src) List<int>.of(t)];

  void _buildLevel() {
    final n = _colorCount;
    List<List<int>> tubes;
    do {
      final units = <int>[
        for (var c = 0; c < n; c++)
          for (var k = 0; k < _cap; k++) c,
      ]..shuffle(_rnd);
      tubes = [
        for (var i = 0; i < n; i++) units.sublist(i * _cap, (i + 1) * _cap),
        <int>[],
        <int>[],
      ];
    } while (_isSolved(tubes));
    _initial = _copy(tubes);
    _tubes = tubes;
    _history.clear();
    _moves = 0;
    _sel = null;
    _locked = false;
  }

  void _restart() {
    setState(() {
      _tubes = _copy(_initial);
      _history.clear();
      _moves = 0;
      _sel = null;
    });
  }

  void _undo() {
    if (_locked || _history.isEmpty) return;
    setState(() {
      _tubes = _history.removeLast();
      _moves = math.max(0, _moves - 1);
      _sel = null;
    });
  }

  bool _canPour(int a, int b) {
    final from = _tubes[a];
    final to = _tubes[b];
    if (from.isEmpty || to.length >= _cap) return false;
    return to.isEmpty || to.last == from.last;
  }

  void _tap(int i) {
    if (_locked) return;
    final sel = _sel;
    if (sel == null) {
      if (_tubes[i].isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _sel = i);
      return;
    }
    if (sel == i) {
      setState(() => _sel = null);
      return;
    }
    if (_canPour(sel, i)) {
      _pour(sel, i);
    } else {
      Sfx.wrong();
      setState(() => _sel = _tubes[i].isEmpty ? null : i);
    }
  }

  void _pour(int a, int b) {
    _history.add(_copy(_tubes));
    final from = _tubes[a];
    final to = _tubes[b];
    final color = from.last;
    while (from.isNotEmpty && from.last == color && to.length < _cap) {
      to.add(from.removeLast());
    }
    HapticFeedback.lightImpact();
    setState(() {
      _moves++;
      _sel = null;
    });
    if (_isSolved(_tubes)) _complete();
  }

  Future<void> _complete() async {
    _locked = true;
    Sfx.correct();
    setState(() => _solvedCount = _level);
    ScoreStore.submit(_id, _solvedCount);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _level++;
      _buildLevel();
    });
  }

  Widget _buildTube(int i) {
    final tube = _tubes[i];
    final selected = _sel == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _tap(i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: selected ? 0 : 14,
          ),
          Container(
            width: 52,
            height: _cap * 38.0 + 18,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(26),
              ),
              border: Border.all(
                color: selected ? Colors.white : const Color(0xFF3A3F55),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final c in tube.reversed)
                  Container(
                    height: 34,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: _colors[c],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
              ],
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
        child: Column(
          children: [
            GameHud(label: t.level(_level), score: _solvedCount, onClose: _close),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _locked
                    ? t.p('Sorted in $_moves moves!', '$_moves hamlede ayırdın!')
                    : t.p('Sort the colors', 'Renkleri ayır'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _locked ? AppColors.good : Colors.white,
                ),
              ),
            ),
            Text(
              t.p('Moves: $_moves', 'Hamle: $_moves'),
              style: const TextStyle(color: AppColors.textDim, fontSize: 14),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 14,
                    runSpacing: 14,
                    children: List<Widget>.generate(_tubes.length, _buildTube),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: _locked || _history.isEmpty ? null : _undo,
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(t.p('Undo', 'Geri al')),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: _locked ? null : _restart,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(t.p('Restart level', 'Bölümü yenile')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
