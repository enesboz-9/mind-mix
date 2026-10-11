import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

enum _Phase { memorize, gap, pick, feedback }

class _Item {
  const _Item(this.icon, this.color);

  final int icon;
  final int color;
}

/// Izgarayı ezberle; kısa bir boşluktan sonra tahta geri gelir ve tek bir kare
/// değişmiştir (simge ya da renk). Değişeni bul. 3 can; ezberleme süresi kısalır.
class SpotChangeScreen extends StatefulWidget {
  const SpotChangeScreen({super.key});

  @override
  State<SpotChangeScreen> createState() => _SpotChangeScreenState();
}

class _SpotChangeScreenState extends State<SpotChangeScreen> {
  static const String _id = 'spot_change';
  static const int _maxLives = 3;
  static const List<IconData> _icons = [
    Icons.favorite_rounded,
    Icons.star_rounded,
    Icons.bolt_rounded,
    Icons.pets_rounded,
    Icons.cloud_rounded,
    Icons.music_note_rounded,
    Icons.local_fire_department_rounded,
    Icons.eco_rounded,
  ];
  static const List<Color> _colors = [
    Color(0xFFFF5E7E),
    Color(0xFFFFC94D),
    Color(0xFF3DDC84),
    Color(0xFF4D9DFF),
    Color(0xFFA472EE),
    Color(0xFFFF8A4D),
  ];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  List<_Item> _a = [];
  List<_Item> _b = [];
  int _changed = 0;
  int? _picked;
  _Phase _phase = _Phase.memorize;

  int _level = 1;
  int _lives = _maxLives;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  int get _size => _level <= 3 ? 3 : 4;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  _Item _randomItem() => _Item(_rnd.nextInt(_icons.length), _rnd.nextInt(_colors.length));

  /// Yeni tur hazırlar ve ezberleme -> boşluk -> seçim zamanlayıcısını kurar.
  void _prepare() {
    _timer?.cancel();
    final n = _size * _size;
    _a = [for (var i = 0; i < n; i++) _randomItem()];
    _b = List<_Item>.of(_a);
    _changed = _rnd.nextInt(n);
    final old = _a[_changed];
    var next = _randomItem();
    while (next.icon == old.icon && next.color == old.color) {
      next = _randomItem();
    }
    _b[_changed] = next;
    _picked = null;
    _phase = _Phase.memorize;

    final showMs = math.max(1400, 3200 - _level * 120);
    _timer = Timer(Duration(milliseconds: showMs), () {
      if (!mounted) return;
      setState(() => _phase = _Phase.gap);
      _timer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() => _phase = _Phase.pick);
      });
    });
  }

  void _start() {
    setState(() {
      _level = 1;
      _lives = _maxLives;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _prepare();
    });
  }

  void _tap(int i) {
    if (_phase != _Phase.pick) return;
    final correct = i == _changed;
    HapticFeedback.selectionClick();
    setState(() {
      _picked = i;
      _phase = _Phase.feedback;
      if (correct) {
        _score++;
      } else {
        _lives--;
      }
    });
    if (correct) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: correct ? 800 : 1200), () {
      if (!mounted) return;
      if (!correct && _lives <= 0) {
        _finish();
        return;
      }
      setState(() {
        if (correct) _level++;
        _prepare();
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

  Widget _buildCell(int i) {
    final show = _phase != _Phase.gap;
    final item = _phase == _Phase.memorize ? _a[i] : _b[i];
    var border = const Color(0xFF3A3F55);
    var bg = AppColors.surface;
    if (_phase == _Phase.feedback) {
      if (i == _changed) {
        border = AppColors.good;
        bg = AppColors.good.withAlpha(40);
      } else if (i == _picked) {
        border = AppColors.bad;
        bg = AppColors.bad.withAlpha(40);
      }
    }
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 2),
        ),
        child: Center(
          child: show
              ? Icon(
                  _icons[item.icon],
                  color: _colors[item.color],
                  size: _size == 3 ? 40 : 30,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final String status;
    var statusColor = Colors.white;
    switch (_phase) {
      case _Phase.memorize:
        status = t.p('Memorize!', 'Ezberle!');
        break;
      case _Phase.gap:
        status = t.p('Get ready…', 'Hazırlan…');
        break;
      case _Phase.pick:
        status = t.p('What changed?', 'Ne değişti?');
        break;
      case _Phase.feedback:
        final ok = _picked == _changed;
        status = ok ? t.p('Spot on!', 'Tam isabet!') : t.p('Missed it', 'Kaçırdın');
        statusColor = ok ? AppColors.good : AppColors.bad;
        break;
    }

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
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
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
                              child: GridView.count(
                                crossAxisCount: _size,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                physics: const NeverScrollableScrollPhysics(),
                                children: List<Widget>.generate(_size * _size, _buildCell),
                              ),
                            ),
                          );
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
