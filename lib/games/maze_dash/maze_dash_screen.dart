import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Kaydırarak labirentten çık: sol üstten sağ alttaki yeşil kareye ulaş.
/// Tek yollu koridorlarda top kendiliğinden ilerler, kavşakta durur.
/// Süre akar; her labirent +4 sn kazandırır ve bir sonraki daha büyüktür.
class MazeDashScreen extends StatefulWidget {
  const MazeDashScreen({super.key});

  @override
  State<MazeDashScreen> createState() => _MazeDashScreenState();
}

class _MazeDashScreenState extends State<MazeDashScreen> {
  static const String _id = 'maze_dash';
  static const int _startSeconds = 45;
  static const int _bonusSeconds = 4;

  // Yönler: 0 = yukarı, 1 = sağ, 2 = aşağı, 3 = sol. Bit maskesi: 1 << yön.
  static const List<int> _dr = [-1, 0, 1, 0];
  static const List<int> _dc = [0, 1, 0, -1];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<int> _maze = const [];
  Set<int> _trail = <int>{};
  int _n = 5;
  int _pos = 0;
  int _score = 0;
  int _left = _startSeconds;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  Offset _acc = Offset.zero;

  int get _goal => _n * _n - 1;

  @override
  void initState() {
    super.initState();
    _newMaze();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _over) return;
      setState(() => _left--);
      if (_left <= 0) _finish();
    });
  }

  void _start() {
    setState(() {
      _score = 0;
      _left = _startSeconds;
      _over = false;
      _isNewBest = false;
      _newMaze();
    });
    _startTimer();
  }

  void _newMaze() {
    _n = math.min(5 + _score ~/ 2, 10);
    _maze = _generate(_n);
    _pos = 0;
    _trail = <int>{0};
    _acc = Offset.zero;
  }

  /// Yinelemeli "recursive backtracker": her hücre için açık geçitlerin bit maskesi.
  List<int> _generate(int n) {
    final grid = List<int>.filled(n * n, 0);
    final seen = List<bool>.filled(n * n, false);
    final stack = <int>[0];
    seen[0] = true;
    while (stack.isNotEmpty) {
      final cur = stack.last;
      final r = cur ~/ n;
      final c = cur % n;
      final options = <int>[];
      for (var d = 0; d < 4; d++) {
        final nr = r + _dr[d];
        final nc = c + _dc[d];
        if (nr < 0 || nc < 0 || nr >= n || nc >= n) continue;
        if (!seen[nr * n + nc]) options.add(d);
      }
      if (options.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = options[_rnd.nextInt(options.length)];
      final next = (r + _dr[d]) * n + (c + _dc[d]);
      grid[cur] |= 1 << d;
      grid[next] |= 1 << ((d + 2) % 4);
      seen[next] = true;
      stack.add(next);
    }
    return grid;
  }

  void _onPanStart(DragStartDetails d) => _acc = Offset.zero;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_over) return;
    _acc += d.delta;
    if (_acc.distance < 24) return;
    final int dir;
    if (_acc.dx.abs() > _acc.dy.abs()) {
      dir = _acc.dx > 0 ? 1 : 3;
    } else {
      dir = _acc.dy > 0 ? 2 : 0;
    }
    _acc = Offset.zero;
    _run(dir);
  }

  void _run(int first) {
    var pos = _pos;
    var dir = first;
    final path = <int>[];
    while ((_maze[pos] & (1 << dir)) != 0) {
      pos = (pos ~/ _n + _dr[dir]) * _n + (pos % _n + _dc[dir]);
      path.add(pos);
      if (pos == _goal) break;
      final back = (dir + 2) % 4;
      final exits = <int>[
        for (var k = 0; k < 4; k++)
          if (k != back && (_maze[pos] & (1 << k)) != 0) k,
      ];
      if (exits.length != 1) break;
      dir = exits.first;
    }
    if (path.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pos = pos;
      _trail.addAll(path);
    });
    if (pos == _goal) _solved();
  }

  void _solved() {
    Sfx.correct();
    setState(() {
      _score++;
      _left += _bonusSeconds;
      _newMaze();
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
                    label: t.p('Maze ${_score + 1}', 'Labirent ${_score + 1}'),
                    score: _score,
                    timeText: '${_left}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      t.p('Swipe to reach the green square', 'Kaydır, yeşil kareye ulaş'),
                      style: const TextStyle(color: AppColors.textDim, fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(
                          builder: (context, box) {
                            final side = math.min(box.maxWidth, box.maxHeight);
                            return Center(
                              child: Container(
                                width: side,
                                height: side,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: CustomPaint(
                                  size: Size(side, side),
                                  painter: _MazePainter(
                                    maze: _maze,
                                    n: _n,
                                    pos: _pos,
                                    goal: _goal,
                                    trail: _trail,
                                  ),
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
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter({
    required this.maze,
    required this.n,
    required this.pos,
    required this.goal,
    required this.trail,
  });

  final List<int> maze;
  final int n;
  final int pos;
  final int goal;
  final Set<int> trail;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / n;

    final trailPaint = Paint()..color = AppColors.accent.withAlpha(70);
    for (final i in trail) {
      final center = Offset((i % n + 0.5) * s, (i ~/ n + 0.5) * s);
      canvas.drawCircle(center, s * 0.1, trailPaint);
    }

    final goalRect = Rect.fromLTWH((goal % n) * s, (goal ~/ n) * s, s, s).deflate(s * 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(goalRect, Radius.circular(s * 0.15)),
      Paint()..color = AppColors.good,
    );

    final wall = Paint()
      ..color = AppColors.textDim
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < maze.length; i++) {
      final x = (i % n) * s;
      final y = (i ~/ n) * s;
      final m = maze[i];
      if ((m & 1) == 0) canvas.drawLine(Offset(x, y), Offset(x + s, y), wall);
      if ((m & 2) == 0) canvas.drawLine(Offset(x + s, y), Offset(x + s, y + s), wall);
      if ((m & 4) == 0) canvas.drawLine(Offset(x, y + s), Offset(x + s, y + s), wall);
      if ((m & 8) == 0) canvas.drawLine(Offset(x, y), Offset(x, y + s), wall);
    }

    final player = Offset((pos % n + 0.5) * s, (pos ~/ n + 0.5) * s);
    canvas.drawCircle(player, s * 0.3, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}
