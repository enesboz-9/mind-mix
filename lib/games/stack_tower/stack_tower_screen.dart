import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_loop.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';

class _Layer {
  const _Layer(this.left, this.width);

  final double left; // 0..1
  final double width; // 0..1
}

/// Kayan bloğu doğru anda bırak, kuleyi yükselt. Taşan kısım kesilir.
class StackTowerScreen extends StatefulWidget {
  const StackTowerScreen({super.key});

  @override
  State<StackTowerScreen> createState() => _StackTowerScreenState();
}

class _StackTowerScreenState extends State<StackTowerScreen>
    with SingleTickerProviderStateMixin {
  static const String _id = 'stack_tower';
  static const double _layerH = 30;
  static const double _perfect = 0.012;

  late final GameLoop _loop;

  final List<_Layer> _layers = [];
  double _mx = 0; // hareketli bloğun sol kenarı
  double _mw = 0.5;
  double _dir = 1;
  int _floors = 0;
  int _score = 0;
  int _combo = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _loop = GameLoop(this, _tick);
    _start();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    setState(() {
      _layers
        ..clear()
        ..add(const _Layer(0.25, 0.5));
      _mw = 0.5;
      _mx = 0;
      _dir = 1;
      _floors = 0;
      _score = 0;
      _combo = 0;
      _over = false;
      _isNewBest = false;
    });
    _loop.start();
  }

  void _tick(double dt) {
    if (_over) return;
    final speed = math.min(1.7, 0.62 + _floors * 0.03);
    _mx += _dir * speed * dt;
    if (_mx <= 0) {
      _mx = 0;
      _dir = 1;
    } else if (_mx >= 1 - _mw) {
      _mx = 1 - _mw;
      _dir = -1;
    }
    setState(() {});
  }

  void _drop() {
    if (_over) return;
    final top = _layers.last;
    final left = math.max(_mx, top.left);
    final right = math.min(_mx + _mw, top.left + top.width);
    final overlap = right - left;
    if (overlap <= 0.008) {
      _finish();
      return;
    }
    HapticFeedback.selectionClick();
    Sfx.correct();
    setState(() {
      if ((_mx - top.left).abs() < _perfect) {
        _layers.add(_Layer(top.left, top.width));
        _mw = math.min(0.6, top.width + (_combo >= 2 ? 0.02 : 0.0));
        _combo++;
        _score += 3;
      } else {
        _layers.add(_Layer(left, overlap));
        _mw = overlap;
        _combo = 0;
        _score += 1;
      }
      _floors++;
      // Yeni blok bir sonraki taraftan başlar.
      _dir = _floors.isEven ? 1 : -1;
      _mx = _dir > 0 ? 0 : 1 - _mw;
    });
  }

  Future<void> _finish() async {
    _loop.stop();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    Sfx.wrong();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Color _color(int i) => HSLColor.fromAHSL(1, (i * 22.0) % 360, 0.7, 0.58).toColor();

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
                extra: t.p('Floors: $_floors', 'Kat: $_floors'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Floors $_floors', 'Kat $_floors'),
                    score: _score,
                    onClose: _close,
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final w = box.maxWidth;
                        final h = box.maxHeight;
                        final movingTop = h * 0.28;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (_) => _drop(),
                          child: ClipRect(
                            child: Stack(
                              children: [
                                for (var i = math.max(0, _layers.length - 30); i < _layers.length; i++)
                                  Positioned(
                                    left: _layers[i].left * w,
                                    top: movingTop + (_layers.length - i) * _layerH,
                                    child: Container(
                                      width: _layers[i].width * w,
                                      height: _layerH - 2,
                                      decoration: BoxDecoration(
                                        color: _color(i),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  left: _mx * w,
                                  top: movingTop,
                                  child: Container(
                                    width: _mw * w,
                                    height: _layerH - 2,
                                    decoration: BoxDecoration(
                                      color: _color(_layers.length),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: 16,
                                  child: Text(
                                    t.p('Tap to drop', 'Bırakmak için dokun'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white38),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
