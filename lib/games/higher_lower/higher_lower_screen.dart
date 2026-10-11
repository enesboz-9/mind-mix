import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const Color _hlColor = Color(0xFF5EEAD4);

/// Sıradaki sayı şimdikinden büyük mü küçük mü? 1-100 arası. Seri yaptıkça puan artar.
class HigherLowerScreen extends StatefulWidget {
  const HigherLowerScreen({super.key});

  @override
  State<HigherLowerScreen> createState() => _HigherLowerScreenState();
}

class _HigherLowerScreenState extends State<HigherLowerScreen> {
  static const String _id = 'higher_lower';
  static const int _maxLives = 3;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _current = 50;
  int _next = 51;
  bool _revealed = false;
  bool _lastOk = false;
  int _streak = 0;
  int _score = 0;
  int _lives = _maxLives;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _deal(fresh: true);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  /// Sayıları hazırlar (setState çağırmaz).
  void _deal({bool fresh = false}) {
    if (fresh) {
      _current = 1 + _rnd.nextInt(100);
    } else {
      _current = _next;
    }
    do {
      _next = 1 + _rnd.nextInt(100);
    } while (_next == _current);
    _revealed = false;
  }

  void _start() {
    _timer?.cancel();
    setState(() {
      _streak = 0;
      _score = 0;
      _lives = _maxLives;
      _over = false;
      _isNewBest = false;
      _deal(fresh: true);
    });
  }

  void _guess(bool higher) {
    if (_revealed || _over) return;
    final ok = higher ? _next > _current : _next < _current;
    if (ok) {
      HapticFeedback.selectionClick();
      Sfx.correct();
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
    }
    setState(() {
      _revealed = true;
      _lastOk = ok;
      if (ok) {
        _streak++;
        _score += 10 + math.min(_streak - 1, 10) * 2;
      } else {
        _streak = 0;
        _lives--;
      }
    });
    _timer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_lives <= 0) {
        _finish();
      } else {
        setState(_deal);
      }
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

  Widget _card(String text, Color color, {Color? border}) {
    return Container(
      width: 130,
      height: 170,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border ?? Colors.transparent, width: 3),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color),
      ),
    );
  }

  Widget _button(String label, IconData icon, bool higher) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 72,
          child: FilledButton.tonal(
            onPressed: _revealed ? null : () => _guess(higher),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26),
                  const SizedBox(width: 6),
                  Text(label, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final resultColor = _lastOk ? AppColors.good : AppColors.bad;
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
                    label: t.p('Streak $_streak', 'Seri $_streak'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p(
                                'Will the next number be higher or lower?',
                                'Sıradaki sayı büyük mü küçük mü?',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _card('$_current', Colors.white),
                                const SizedBox(width: 16),
                                _revealed
                                    ? _card('$_next', resultColor, border: resultColor)
                                    : _card('?', _hlColor, border: _hlColor.withAlpha(90)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Row(
                        children: [
                          _button(t.p('Lower', 'Küçük'), Icons.arrow_downward_rounded, false),
                          _button(t.p('Higher', 'Büyük'), Icons.arrow_upward_rounded, true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
