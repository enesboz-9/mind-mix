import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Hedef rengi R / G / B kaydırıcılarıyla karıştırarak yakala. 5 tur; her tur
/// en fazla 100 puan (toplam 500). Hata payı arttıkça puan hızla düşer.
class ColorMixerScreen extends StatefulWidget {
  const ColorMixerScreen({super.key});

  @override
  State<ColorMixerScreen> createState() => _ColorMixerScreenState();
}

class _ColorMixerScreenState extends State<ColorMixerScreen> {
  static const String _id = 'color_mixer';
  static const int _rounds = 5;
  static const double _maxDist = 441.67; // sqrt(3 * 255^2)

  final math.Random _rnd = math.Random();

  int _tr = 0;
  int _tg = 0;
  int _tb = 0;
  double _r = 128;
  double _g = 128;
  double _b = 128;

  int _round = 1;
  int _score = 0;
  int _best = 0;
  int _gain = 0;
  int _matchPct = 0;
  bool _checked = false;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _newTarget();
  }

  void _close() => Navigator.of(context).pop();

  void _newTarget() {
    _tr = _rnd.nextInt(256);
    _tg = _rnd.nextInt(256);
    _tb = _rnd.nextInt(256);
    _r = 128;
    _g = 128;
    _b = 128;
    _checked = false;
  }

  void _start() {
    setState(() {
      _round = 1;
      _score = 0;
      _gain = 0;
      _matchPct = 0;
      _over = false;
      _isNewBest = false;
      _newTarget();
    });
  }

  void _check() {
    final dr = _r - _tr;
    final dg = _g - _tg;
    final db = _b - _tb;
    final err = math.sqrt(dr * dr + dg * dg + db * db) / _maxDist * 100;
    final gain = math.max(0, 100 - (err * 3).round());
    HapticFeedback.selectionClick();
    if (gain >= 60) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    setState(() {
      _matchPct = (100 - err).clamp(0, 100).round();
      _gain = gain;
      _score += gain;
      _checked = true;
    });
  }

  void _next() {
    if (_round >= _rounds) {
      _finish();
      return;
    }
    setState(() {
      _round++;
      _newTarget();
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

  Widget _swatch(String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textDim,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slider(String name, double value, Color color, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 22,
          child: Text(
            name,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 255,
            activeColor: color,
            onChanged: _checked ? null : onChanged,
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value.round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(color: AppColors.textDim, fontSize: 14),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final target = Color.fromARGB(255, _tr, _tg, _tb);
    final mix = Color.fromARGB(255, _r.round(), _g.round(), _b.round());
    final String buttonLabel;
    if (!_checked) {
      buttonLabel = t.p('Check', 'Kontrol et');
    } else if (_round >= _rounds) {
      buttonLabel = t.p('Finish', 'Bitir');
    } else {
      buttonLabel = t.p('Next', 'Sonraki');
    }

    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Out of 500', '500 üzerinden'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Round $_round/$_rounds', 'Tur $_round/$_rounds'),
                    score: _score,
                    onClose: _close,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _swatch(t.p('Target', 'Hedef'), target),
                              const SizedBox(width: 14),
                              _swatch(t.p('Yours', 'Seninki'), mix),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _slider('R', _r, const Color(0xFFFF5E7E), (v) => setState(() => _r = v)),
                          _slider('G', _g, const Color(0xFF3DDC84), (v) => setState(() => _g = v)),
                          _slider('B', _b, const Color(0xFF4D9DFF), (v) => setState(() => _b = v)),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 28,
                            child: _checked
                                ? Text(
                                    t.p(
                                      'Match $_matchPct%   +$_gain',
                                      'Benzerlik $_matchPct%   +$_gain',
                                    ),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _gain >= 60 ? AppColors.good : AppColors.accent,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 12),
                          PillButton(
                            label: buttonLabel,
                            onPressed: _checked ? _next : _check,
                          ),
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
