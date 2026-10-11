import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Karışık harflerden kelimeyi kur. 60 saniye; yanlış deneme 3, atlama 5 saniye götürür.
class WordScrambleScreen extends StatefulWidget {
  const WordScrambleScreen({super.key});

  @override
  State<WordScrambleScreen> createState() => _WordScrambleScreenState();
}

class _WordScrambleScreenState extends State<WordScrambleScreen> {
  static const String _id = 'word_scramble';
  static const int _totalMs = 60000;
  static const List<String> _en = [
    'APPLE', 'BREAD', 'CHAIR', 'DREAM', 'EARTH', 'FLAME', 'GRAPE', 'HOUSE', 'LEMON',
    'MUSIC', 'NIGHT', 'OCEAN', 'PIANO', 'QUEEN', 'RIVER', 'SMILE', 'TABLE', 'WATER',
    'BRIDGE', 'CASTLE', 'DRAGON', 'FOREST', 'GARDEN', 'ORANGE', 'PLANET', 'ROCKET',
    'SILVER', 'THUNDER', 'MONSTER', 'PUZZLE', 'LIBRARY', 'JOURNEY',
  ];
  static const List<String> _tr = [
    'KALEM', 'KİTAP', 'ÇİÇEK', 'DENİZ', 'ELMA', 'GÜNEŞ', 'KAPI', 'MASA', 'OKUL',
    'SAAT', 'YILDIZ', 'BULUT', 'ARABA', 'BALIK', 'ÇOCUK', 'DÜNYA', 'GÖKYÜZÜ', 'KEDİ',
    'ORMAN', 'PENCERE', 'SİMİT', 'TAVŞAN', 'UÇAK', 'ZAMAN', 'BAHÇE', 'MUTLU',
    'ÖĞRETMEN', 'KÖPRÜ', 'TELEFON', 'ÇANTA',
  ];

  final math.Random _rnd = math.Random();
  Timer? _timer;

  bool _inited = false;
  bool _tr0 = false;
  String _word = '';
  List<String> _tiles = [];
  final List<int> _built = [];
  int _timeMs = _totalMs;
  int _score = 0;
  int _solved = 0;
  int _best = 0;
  bool _shake = false;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inited) {
      _inited = true;
      _tr0 = SettingsScope.of(context).t.isTr;
      _reset();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _reset() {
    _timeMs = _totalMs;
    _score = 0;
    _solved = 0;
    _over = false;
    _isNewBest = false;
    _newWord();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      _timeMs -= 100;
      if (_timeMs <= 0) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _start() {
    setState(_reset);
    _startTimer();
  }

  void _newWord() {
    final list = _tr0 ? _tr : _en;
    final prev = _word;
    var w = list[_rnd.nextInt(list.length)];
    while (w == prev && list.length > 1) {
      w = list[_rnd.nextInt(list.length)];
    }
    _word = w;
    final letters = w.split('');
    var tries = 0;
    do {
      letters.shuffle(_rnd);
      tries++;
    } while (letters.join() == w && tries < 20);
    _tiles = letters;
    _built.clear();
  }

  void _tapTile(int i) {
    if (_over || _built.contains(i)) return;
    HapticFeedback.selectionClick();
    setState(() => _built.add(i));
    if (_built.length == _tiles.length) _check();
  }

  void _check() {
    final guess = _built.map((i) => _tiles[i]).join();
    if (guess == _word) {
      Sfx.correct();
      setState(() {
        _score += 10 + _word.length * 2;
        _solved++;
        _newWord();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      _timeMs -= 3000;
      if (_timeMs <= 0) {
        _finish();
        return;
      }
      setState(() {
        _shake = true;
        _built.clear();
      });
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (mounted) setState(() => _shake = false);
      });
    }
  }

  void _back() {
    if (_over || _built.isEmpty) return;
    setState(() => _built.removeLast());
  }

  void _skip() {
    if (_over) return;
    _timeMs -= 5000;
    if (_timeMs <= 0) {
      _finish();
    } else {
      setState(_newWord);
    }
  }

  Future<void> _finish() async {
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _timeMs = 0;
      _over = true;
    });
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
    final len = _tiles.length;
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Words solved: $_solved', 'Bulunan kelime: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Words $_solved', 'Kelime $_solved'),
                    score: _score,
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
                  Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      t.p('Unscramble the word', 'Kelimeyi bul'),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Kurulan kelime
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var k = 0; k < len; k++)
                                Container(
                                  width: 42,
                                  height: 52,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _shake ? AppColors.bad : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Text(
                                    k < _built.length ? _tiles[_built[k]] : '',
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 36),
                          // Karışık harfler
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (var i = 0; i < len; i++)
                                GestureDetector(
                                  onTap: () => _tapTile(i),
                                  child: Container(
                                    width: 52,
                                    height: 60,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _built.contains(i)
                                          ? Colors.white10
                                          : AppColors.accent,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text(
                                      _built.contains(i) ? '' : _tiles[i],
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: _back,
                                icon: const Icon(Icons.backspace_rounded),
                                label: Text(t.p('Undo', 'Geri al')),
                              ),
                              const SizedBox(width: 12),
                              TextButton.icon(
                                onPressed: _skip,
                                icon: const Icon(Icons.skip_next_rounded),
                                label: Text(t.p('Skip (-5s)', 'Atla (-5sn)')),
                              ),
                            ],
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
