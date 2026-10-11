import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _moleColor = Color(0xFFD97706);

class _Hole {
  /// 0 boş, 1 köstebek, 2 bomba
  int kind = 0;
  int lastKind = 1;
  int msLeft = 0;
}

/// Köstebeklere dokun, bombalardan kaç. 30 saniye, 3 can.
class MoleHuntScreen extends StatefulWidget {
  const MoleHuntScreen({super.key});

  @override
  State<MoleHuntScreen> createState() => _MoleHuntScreenState();
}

class _MoleHuntScreenState extends State<MoleHuntScreen> {
  static const String _id = 'mole_hunt';
  static const int _maxLives = 3;
  static const int _totalMs = 30000;

  final math.Random _rnd = math.Random();
  final List<_Hole> _holes = [for (var i = 0; i < 9; i++) _Hole()];
  Timer? _ticker;

  int _elapsed = 0;
  int _spawnIn = 300;
  int _lives = _maxLives;
  int _hits = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _score => _hits * 10;
  int get _secsLeft => math.max(0, ((_totalMs - _elapsed) / 1000).ceil());

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

  void _start() {
    _ticker?.cancel();
    setState(() {
      for (final h in _holes) {
        h.kind = 0;
        h.msLeft = 0;
      }
      _elapsed = 0;
      _spawnIn = 300;
      _lives = _maxLives;
      _hits = 0;
      _over = false;
      _isNewBest = false;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _spawn() {
    final empty = [
      for (var i = 0; i < _holes.length; i++)
        if (_holes[i].kind == 0) i,
    ];
    if (empty.isEmpty) return;
    final h = _holes[empty[_rnd.nextInt(empty.length)]];
    final bomb = _hits >= 5 && _rnd.nextInt(100) < 25;
    h.kind = bomb ? 2 : 1;
    h.lastKind = h.kind;
    h.msLeft = math.max(500, 1200 - _hits * 15);
  }

  void _tick() {
    if (!mounted || _over) return;
    setState(() {
      _elapsed += 100;
      for (final h in _holes) {
        if (h.kind != 0) {
          h.msLeft -= 100;
          if (h.msLeft <= 0) h.kind = 0;
        }
      }
      _spawnIn -= 100;
      if (_spawnIn <= 0) {
        _spawn();
        _spawnIn = math.max(400, 900 - _hits * 10);
      }
    });
    if (_elapsed >= _totalMs) _finish();
  }

  void _tap(int i) {
    if (_over) return;
    final h = _holes[i];
    if (h.kind == 1) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _hits++;
        h.kind = 0;
      });
    } else if (h.kind == 2) {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        h.kind = 0;
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

  Widget _hole(int i) {
    final h = _holes[i];
    final bomb = h.lastKind == 2;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(i),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: _moleColor.withAlpha(70), width: 3),
        ),
        child: Center(
          child: AnimatedScale(
            scale: h.kind == 0 ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutBack,
            child: Icon(
              bomb ? Icons.dangerous_rounded : Icons.pets_rounded,
              size: 46,
              color: bomb ? AppColors.bad : _moleColor,
            ),
          ),
        ),
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
                extra: t.p('Moles hit: $_hits', 'Vurulan köstebek: $_hits'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Hits $_hits', 'Vuruş $_hits'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_secsLeft}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      t.p('Hit the moles, avoid the bombs', 'Köstebeklere vur, bombalardan kaç'),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          padding: const EdgeInsets.all(20),
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          children: [for (var i = 0; i < _holes.length; i++) _hole(i)],
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
