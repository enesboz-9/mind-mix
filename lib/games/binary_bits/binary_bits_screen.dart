import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Hedef sayıyı ikilik tabandaki bitleri açıp kapatarak yap. 45 saniye.
/// Bitler soldan sağa 8, 4, 2, 1 (ilerledikçe 16 ve 32 de eklenir).
class BinaryBitsScreen extends StatefulWidget {
  const BinaryBitsScreen({super.key});

  @override
  State<BinaryBitsScreen> createState() => _BinaryBitsScreenState();
}

class _BinaryBitsScreenState extends State<BinaryBitsScreen> {
  static const String _id = 'binary_bits';
  static const int _totalSeconds = 45;

  final math.Random _rnd = math.Random();
  Timer? _timer;

  int _bits = 4;
  late List<bool> _on;
  int _target = 0;
  int _left = _totalSeconds;
  int _solved = 0;
  int _score = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _flash = false;

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
      _left = _totalSeconds;
      _solved = 0;
      _score = 0;
      _over = false;
      _isNewBest = false;
      _flash = false;
    });
    _next();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 1) {
        setState(() => _left = 0);
        _finish();
      } else {
        setState(() => _left--);
      }
    });
  }

  void _next() {
    _bits = _solved < 4 ? 4 : (_solved < 9 ? 5 : 6);
    final max = (1 << _bits) - 1;
    var n = 1 + _rnd.nextInt(max);
    while (n == _target) {
      n = 1 + _rnd.nextInt(max);
    }
    setState(() {
      _target = n;
      _on = List.filled(_bits, false);
    });
  }

  int get _value {
    var v = 0;
    for (var i = 0; i < _bits; i++) {
      if (_on[i]) v += 1 << (_bits - 1 - i);
    }
    return v;
  }

  Future<void> _toggle(int i) async {
    if (_over || _flash) return;
    HapticFeedback.selectionClick();
    setState(() => _on[i] = !_on[i]);
    if (_value == _target) {
      Sfx.correct();
      _solved++;
      setState(() {
        _score += 10 + _bits * 2;
        _flash = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 280));
      if (!mounted || _over) return;
      setState(() => _flash = false);
      _next();
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    Sfx.over();
    setState(() => _over = true);
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
                extra: t.p('Numbers solved: $_solved', 'Çözülen sayı: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Binary Bits', 'İkilik Bitler'),
                    score: _score,
                    timeText: '${_left}s',
                    onClose: _close,
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.p('Make this number', 'Bu sayıyı yap'),
                              style: const TextStyle(color: AppColors.textDim, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_target',
                              style: TextStyle(
                                fontSize: 96,
                                fontWeight: FontWeight.w900,
                                color: _flash ? AppColors.good : Colors.white,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              t.p('Current: $_value', 'Şu an: $_value'),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (var i = 0; i < _bits; i++)
                                  GestureDetector(
                                    onTap: () => _toggle(i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      width: 52,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        color: _on[i] ? const Color(0xFF4D9DFF) : AppColors.surface,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: _on[i] ? Colors.white : AppColors.textDim,
                                          width: 2,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _on[i] ? '1' : '0',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${1 << (_bits - 1 - i)}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              color: Colors.white70,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
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
