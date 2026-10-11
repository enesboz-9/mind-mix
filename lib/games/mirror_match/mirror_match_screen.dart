import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

typedef _Cells = List<(int, int)>;

const Color _shapeColor = Color(0xFFE879F9);

/// Üstteki şeklin yalnızca döndürülmüş hâlini bul; diğer seçenekler aynanın
/// ters çevirdiği (yansıma) şekillerdir. 3 can; şekiller büyüdükçe zorlaşır.
class MirrorMatchScreen extends StatefulWidget {
  const MirrorMatchScreen({super.key});

  @override
  State<MirrorMatchScreen> createState() => _MirrorMatchScreenState();
}

class _MirrorMatchScreenState extends State<MirrorMatchScreen> {
  static const String _id = 'mirror_match';
  static const int _maxLives = 3;
  static const List<(int, int)> _dirs = [(1, 0), (-1, 0), (0, 1), (0, -1)];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  _Cells _reference = [];
  List<_Cells> _options = [];
  int _correct = 0;
  int? _picked;

  int _level = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  bool _locked = false;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  // --- Şekil işlemleri -----------------------------------------------------

  _Cells _norm(Iterable<(int, int)> cells) {
    final list = cells.toList();
    final minR = list.map((e) => e.$1).reduce(math.min);
    final minC = list.map((e) => e.$2).reduce(math.min);
    final out = <(int, int)>[for (final e in list) (e.$1 - minR, e.$2 - minC)];
    out.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return out;
  }

  _Cells _rotate(_Cells s) => _norm([for (final e in s) (e.$2, -e.$1)]);

  _Cells _mirror(_Cells s) => _norm([for (final e in s) (e.$1, -e.$2)]);

  String _key(_Cells s) => s.map((e) => '${e.$1},${e.$2}').join(';');

  _Cells _randomShape() {
    final n = _level >= 5 ? 7 : (_level >= 3 ? 6 : 5);
    while (true) {
      final cells = <(int, int)>{(0, 0)};
      var guard = 0;
      while (cells.length < n && guard++ < 200) {
        final base = cells.elementAt(_rnd.nextInt(cells.length));
        final d = _dirs[_rnd.nextInt(_dirs.length)];
        final next = (base.$1 + d.$1, base.$2 + d.$2);
        if (cells.contains(next)) continue;
        final test = _norm([...cells, next]);
        final h = test.map((e) => e.$1).reduce(math.max) + 1;
        final w = test.map((e) => e.$2).reduce(math.max) + 1;
        if (h > 4 || w > 4) continue;
        cells.add(next);
      }
      if (cells.length == n) return _norm(cells);
    }
  }

  void _newRound() {
    _timer?.cancel();
    while (true) {
      final shape = _randomShape();
      final rots = <_Cells>[shape];
      for (var i = 0; i < 3; i++) {
        rots.add(_rotate(rots.last));
      }
      final mirrors = <_Cells>[_mirror(shape)];
      for (var i = 0; i < 3; i++) {
        mirrors.add(_rotate(mirrors.last));
      }
      final rotKeys = rots.map(_key).toSet();
      final mirByKey = <String, _Cells>{for (final m in mirrors) _key(m): m};
      // Yansıması kendisine dönüşen (simetrik) şekilleri ele.
      if (mirByKey.keys.any(rotKeys.contains)) continue;
      if (mirByKey.length < 3) continue;

      final correct = rots[1 + _rnd.nextInt(3)];
      final wrong = mirByKey.values.toList()..shuffle(_rnd);
      final options = <_Cells>[correct, ...wrong.take(3)]..shuffle(_rnd);
      _reference = shape;
      _options = options;
      _correct = options.indexWhere((o) => identical(o, correct));
      _picked = null;
      _locked = false;
      return;
    }
  }

  void _start() {
    setState(() {
      _level = 1;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _newRound();
    });
  }

  void _tap(int i) {
    if (_locked) return;
    final ok = i == _correct;
    HapticFeedback.selectionClick();
    setState(() {
      _locked = true;
      _picked = i;
      if (ok) {
        _score++;
      } else {
        _lives--;
      }
    });
    if (ok) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    _timer = Timer(Duration(milliseconds: ok ? 600 : 1100), () {
      if (!mounted) return;
      if (!ok && _lives <= 0) {
        _finish();
        return;
      }
      setState(() {
        if (ok) _level++;
        _newRound();
      });
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _option(int i) {
    var border = const Color(0xFF3A3F55);
    if (_locked) {
      if (i == _correct) {
        border = AppColors.good;
      } else if (i == _picked) {
        border = AppColors.bad;
      }
    }
    return GestureDetector(
      onTap: () => _tap(i),
      child: Container(
        width: 130,
        height: 130,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border, width: 3),
        ),
        child: CustomPaint(painter: _ShapePainter(_options[i])),
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
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              t.p(
                                'Which one is the same shape, only rotated?',
                                'Hangisi aynı şeklin yalnızca döndürülmüşü?',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 120,
                              height: 120,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _shapeColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _shapeColor, width: 2),
                              ),
                              child: CustomPaint(painter: _ShapePainter(_reference)),
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 14,
                              runSpacing: 14,
                              children: List<Widget>.generate(_options.length, _option),
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

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.cells);

  final _Cells cells;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 4;
    final paint = Paint()..color = _shapeColor;
    if (cells.isEmpty) return;
    final h = cells.map((e) => e.$1).reduce(math.max) + 1;
    final w = cells.map((e) => e.$2).reduce(math.max) + 1;
    final offX = (4 - w) * s / 2;
    final offY = (4 - h) * s / 2;
    for (final c in cells) {
      final rect = Rect.fromLTWH(offX + c.$2 * s, offY + c.$1 * s, s, s).deflate(1.5);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.18)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ShapePainter old) => !identical(old.cells, cells);
}
