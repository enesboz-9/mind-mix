import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const List<String> _poolEn = [
  'apple', 'river', 'chair', 'cloud', 'tiger', 'piano', 'bread', 'stone',
  'train', 'lemon', 'ocean', 'candle', 'window', 'garden', 'rocket', 'mirror',
  'pencil', 'bridge', 'forest', 'planet', 'basket', 'camera', 'dragon',
  'honey', 'jacket', 'kettle', 'ladder', 'magnet', 'napkin', 'pillow',
  'rabbit', 'spoon', 'tunnel', 'violin', 'wallet', 'zebra',
];

const List<String> _poolTr = [
  'elma', 'nehir', 'sandalye', 'bulut', 'kaplan', 'piyano', 'ekmek', 'taş',
  'tren', 'limon', 'okyanus', 'mum', 'pencere', 'bahçe', 'roket', 'ayna',
  'kalem', 'köprü', 'orman', 'gezegen', 'sepet', 'kamera', 'ejderha', 'bal',
  'ceket', 'çaydanlık', 'merdiven', 'mıknatıs', 'peçete', 'yastık', 'tavşan',
  'kaşık', 'tünel', 'keman', 'cüzdan', 'zebra',
];

enum _Phase { show, pick, done }

/// Kelimeleri kısa süre göster, sonra karışık listeden gördüklerini bul. 3 can.
class WordRecallScreen extends StatefulWidget {
  const WordRecallScreen({super.key});

  @override
  State<WordRecallScreen> createState() => _WordRecallScreenState();
}

class _WordRecallScreenState extends State<WordRecallScreen> {
  static const String _id = 'word_recall';

  final math.Random _rnd = math.Random();

  List<String> _targets = [];
  List<String> _cards = [];
  final Set<String> _found = {};
  String? _wrong;
  _Phase _phase = _Phase.show;
  int _level = 1;
  int _lives = 3;
  int _score = 0;
  int _best = 0;
  int _gen = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _isTr = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _gen++;
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _start() {
    _isTr = AppSettings.instance.lang == 'tr';
    setState(() {
      _level = 1;
      _lives = 3;
      _score = 0;
      _over = false;
      _isNewBest = false;
    });
    _round();
  }

  Future<void> _round() async {
    final gen = ++_gen;
    final count = math.min(6, 3 + (_level - 1) ~/ 2);
    final pool = List<String>.of(_isTr ? _poolTr : _poolEn)..shuffle(_rnd);
    final targets = pool.sublist(0, count);
    final decoys = pool.sublist(count, count * 2);
    final cards = [...targets, ...decoys]..shuffle(_rnd);
    setState(() {
      _targets = targets;
      _cards = cards;
      _found.clear();
      _wrong = null;
      _phase = _Phase.show;
    });
    final showMs = 1500 + count * 700;
    await Future<void>.delayed(Duration(milliseconds: showMs));
    if (!mounted || gen != _gen) return;
    setState(() => _phase = _Phase.pick);
  }

  Future<void> _tap(String w) async {
    if (_phase != _Phase.pick || _over || _found.contains(w)) return;
    if (_targets.contains(w)) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _found.add(w);
        _score += 5;
      });
      if (_found.length == _targets.length) {
        setState(() {
          _phase = _Phase.done;
          _score += 10;
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        _level++;
        _round();
      }
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() {
        _lives--;
        _wrong = w;
        _phase = _Phase.done;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (_lives <= 0) {
        await _finish();
      } else {
        _round();
      }
    }
  }

  Future<void> _finish() async {
    Sfx.over();
    setState(() => _over = true);
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Color _cardColor(String w) {
    if (w == _wrong) return AppColors.bad;
    if (_found.contains(w)) return AppColors.good;
    if (_phase == _Phase.done && _wrong != null && _targets.contains(w)) {
      return AppColors.accent;
    }
    return AppColors.surface;
  }

  @override
  Widget build(BuildContext context) {
    final t = SettingsScope.of(context).t;
    final String hint;
    switch (_phase) {
      case _Phase.show:
        hint = t.p('Memorize these words', 'Bu kelimeleri aklında tut');
        break;
      case _Phase.pick:
        hint = t.p('Tap the words you saw', 'Gördüğün kelimelere dokun');
        break;
      case _Phase.done:
        hint = '';
        break;
    }
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Reached level $_level', '$_level. seviyeye ulaştın'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.level(_level),
                    score: _score,
                    lives: _lives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      hint,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: _phase == _Phase.show
                              ? [
                                  for (final w in _targets)
                                    _chip(w, AppColors.accent, () {}),
                                ]
                              : [
                                  for (final w in _cards)
                                    _chip(w, _cardColor(w), () => _tap(w)),
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

  Widget _chip(String w, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        child: Text(
          w,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
