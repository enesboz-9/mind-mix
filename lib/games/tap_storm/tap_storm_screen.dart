import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// 10 saniyede olabildiğince çok dokun. İlk dokunuşta süre başlar.
class TapStormScreen extends StatefulWidget {
  const TapStormScreen({super.key});

  @override
  State<TapStormScreen> createState() => _TapStormScreenState();
}

class _TapStormScreenState extends State<TapStormScreen> {
  static const String _id = 'tap_storm';
  static const int _totalMs = 10000;

  Timer? _timer;

  int _taps = 0;
  int _timeMs = _totalMs;
  int _best = 0;
  bool _running = false;
  bool _pressed = false;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    _timer?.cancel();
    setState(() {
      _taps = 0;
      _timeMs = _totalMs;
      _running = false;
      _pressed = false;
      _over = false;
      _isNewBest = false;
    });
  }

  void _tap() {
    if (_over) return;
    if (!_running) {
      _running = true;
      _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted) return;
        _timeMs -= 50;
        if (_timeMs <= 0) {
          _finish();
        } else {
          setState(() {});
        }
      });
    }
    HapticFeedback.selectionClick();
    setState(() {
      _taps++;
      _pressed = true;
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timeMs = 0;
      _over = true;
    });
    Sfx.over();
    final r = await ScoreStore.record(_id, _taps);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final tapsPerSec = (_totalMs - _timeMs) > 0
        ? (_taps / ((_totalMs - _timeMs) / 1000)).toStringAsFixed(1)
        : '0.0';
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _taps,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('${(_taps / 10).toStringAsFixed(1)} taps / sec',
                    'Saniyede ${(_taps / 10).toStringAsFixed(1)} dokunuş'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('$tapsPerSec / sec', 'Saniyede $tapsPerSec'),
                    score: _taps,
                    timeText: '${(_timeMs / 1000).ceil()}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_timeMs / _totalMs).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (_) => _tap(),
                        onTapUp: (_) => setState(() => _pressed = false),
                        onTapCancel: () => setState(() => _pressed = false),
                        child: AnimatedScale(
                          scale: _pressed ? 0.92 : 1,
                          duration: const Duration(milliseconds: 70),
                          child: Container(
                            width: 240,
                            height: 240,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppColors.accent, Color(0xFFA472EE)],
                              ),
                            ),
                            child: Text(
                              _running ? '$_taps' : t.p('TAP!', 'DOKUN!'),
                              style: const TextStyle(
                                fontSize: 54,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
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
    );
  }
}
