import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Bir kareye dokununca kendisi ve komşuları değişir; tüm ışıkları söndür.
/// Bölümler "tersine karıştırılarak" üretilir, bu yüzden hepsi çözülebilir.
class LightsOutScreen extends StatefulWidget {
  const LightsOutScreen({super.key});

  @override
  State<LightsOutScreen> createState() => _LightsOutScreenState();
}

class _LightsOutScreenState extends State<LightsOutScreen> {
  static const String _id = 'lights_out';
  static const Color _onColor = Color(0xFFFFC94D);

  final math.Random _rnd = math.Random();

  int _level = 1;
  int _solved = 0;
  int _moves = 0;
  int _size = 3;
  List<bool> _cells = const [];
  List<bool> _initial = const [];
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _buildLevel();
  }

  void _close() => Navigator.of(context).pop();

  int _sizeFor(int level) => level <= 3 ? 3 : (level <= 7 ? 4 : 5);

  void _toggle(List<bool> cells, int size, int index) {
    final r = index ~/ size;
    final c = index % size;
    void flip(int rr, int cc) {
      if (rr < 0 || cc < 0 || rr >= size || cc >= size) return;
      cells[rr * size + cc] = !cells[rr * size + cc];
    }

    flip(r, c);
    flip(r - 1, c);
    flip(r + 1, c);
    flip(r, c - 1);
    flip(r, c + 1);
  }

  void _buildLevel() {
    _size = _sizeFor(_level);
    final total = _size * _size;
    final presses = math.min(total, 2 + _level);
    List<bool> board;
    do {
      board = List<bool>.filled(total, false);
      final idx = List<int>.generate(total, (i) => i)..shuffle(_rnd);
      for (final i in idx.take(presses)) {
        _toggle(board, _size, i);
      }
    } while (!board.contains(true));
    _initial = List<bool>.of(board);
    _cells = board;
    _moves = 0;
    _locked = false;
  }

  void _restart() {
    setState(() {
      _cells = List<bool>.of(_initial);
      _moves = 0;
    });
  }

  Future<void> _tap(int i) async {
    if (_locked) return;
    HapticFeedback.selectionClick();
    setState(() {
      _toggle(_cells, _size, i);
      _moves++;
    });
    if (_cells.contains(true)) return;

    _locked = true;
    Sfx.correct();
    setState(() => _solved = _level);
    ScoreStore.submit(_id, _solved);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _level++;
      _buildLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            GameHud(label: t.level(_level), score: _solved, onClose: _close),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Text(
                _locked
                    ? t.p('Solved in $_moves moves!', '$_moves hamlede çözdün!')
                    : t.p('Turn off all the lights', 'Tüm ışıkları söndür'),
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
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          physics: const NeverScrollableScrollPhysics(),
                          children: List.generate(_size * _size, (i) {
                            final on = _cells[i];
                            return GestureDetector(
                              onTap: () => _tap(i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  color: on ? _onColor : AppColors.surface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: on
                                      ? [
                                          BoxShadow(
                                            color: _onColor.withAlpha(110),
                                            blurRadius: 18,
                                          ),
                                        ]
                                      : null,
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
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextButton.icon(
                onPressed: _locked ? null : _restart,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t.p('Restart level', 'Bölümü yenile')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
