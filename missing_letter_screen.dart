import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

const List<String> _wordsEn = [
  'PLANET', 'GARDEN', 'BRIDGE', 'CASTLE', 'DRAGON', 'FOREST', 'GUITAR',
  'ISLAND', 'JUNGLE', 'KITCHEN', 'LADDER', 'MIRROR', 'ORANGE', 'PENCIL',
  'ROCKET', 'SUMMER', 'TICKET', 'WINDOW', 'YELLOW', 'ZIPPER', 'BANANA',
  'CANDLE', 'DOCTOR', 'ENGINE', 'FLOWER', 'HAMMER', 'MARKET', 'NUMBER',
  'POCKET', 'SILVER', 'THUNDER', 'TURTLE', 'VIOLIN', 'WINTER', 'BUTTER',
  'COOKIE', 'DINNER', 'FINGER', 'GOLDEN', 'MONKEY', 'PURPLE', 'SPIDER',
  'TEACHER', 'BLANKET', 'COMPASS', 'DIAMOND',
];

const List<String> _wordsTr = [
  'GÜNEŞ', 'ARABA', 'KALEM', 'BULUT', 'DENİZ', 'ÇİÇEK', 'KİTAP', 'MASAL',
  'YILDIZ', 'ÖĞRENCİ', 'TELEFON', 'PENCERE', 'ÇANTA', 'BAHÇE', 'ORMAN',
  'KÖPRÜ', 'TAVŞAN', 'BALIK', 'HAYVAN', 'MUTFAK', 'DEFTER', 'ÖĞRETMEN',
  'ÇOCUK', 'KAPLAN', 'SİNEMA', 'GEZEGEN', 'ROKET', 'SAHİL', 'TARLA',
  'YAĞMUR', 'KARPUZ', 'LİMON', 'PORTAKAL', 'KAPI', 'BAYRAK', 'HİKAYE',
  'MÜZİK', 'RESİM', 'SOKAK', 'KİLİT',
];

const String _alphaEn = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const String _alphaTr = 'ABCÇDEFGĞHIİJKLMNOPRSŞTUÜVYZ';

/// Eksik harfi bul. Her soru için süre kısıtlı; 3 can.
class MissingLetterScreen extends StatefulWidget {
  const MissingLetterScreen({super.key});

  @override
  State<MissingLetterScreen> createState() => _MissingLetterScreenState();
}

class _MissingLetterScreenState extends State<MissingLetterScreen> {
  static const String _id = 'missing_letter';

  final math.Random _rnd = math.Random();
  Timer? _timer;

  String _word = '';
  int _hole = 0;
  List<String> _options = [];
  String? _picked;
  double _total = 8;
  double _remain = 8;
  int _lives = 3;
  int _score = 0;
  int _solved = 0;
  int _best = 0;
  bool _over = false;
  bool _isNewBest = false;
  bool _locked = false;
  bool _isTr = false;
  String _lastWord = '';

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
    _isTr = AppSettings.instance.lang == 'tr';
    setState(() {
      _lives = 3;
      _score = 0;
      _solved = 0;
      _over = false;
      _isNewBest = false;
    });
    _next();
  }

  void _next() {
    _timer?.cancel();
    final words = _isTr ? _wordsTr : _wordsEn;
    final alpha = (_isTr ? _alphaTr : _alphaEn).split('');
    var w = words[_rnd.nextInt(words.length)];
    while (w == _lastWord) {
      w = words[_rnd.nextInt(words.length)];
    }
    _lastWord = w;
    final letters = w.split('');
    // İlk harf hep açık kalır; eksik harf geri kalanlardan seçilir.
    final hole = 1 + _rnd.nextInt(letters.length - 1);
    final answer = letters[hole];

    // Yanlış şıklar: gerçek bir kelime oluşturmayan harfler tercih edilir.
    final wrong = <String>[];
    final pool = List<String>.of(alpha)..shuffle(_rnd);
    for (final ch in pool) {
      if (ch == answer) continue;
      final cand = List<String>.of(letters)..[hole] = ch;
      if (words.contains(cand.join())) continue;
      wrong.add(ch);
      if (wrong.length == 3) break;
    }
    final options = <String>[answer, ...wrong]..shuffle(_rnd);

    setState(() {
      _word = w;
      _hole = hole;
      _options = options;
      _picked = null;
      _locked = false;
      _total = math.max(3.5, 8 - _solved * 0.2);
      _remain = _total;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _locked) return;
      setState(() => _remain -= 0.05);
      if (_remain <= 0) _answer(null);
    });
  }

  Future<void> _answer(String? letter) async {
    if (_locked || _over) return;
    _locked = true;
    _timer?.cancel();
    final correct = letter != null && letter == _word[_hole];
    setState(() => _picked = letter ?? '');
    if (correct) {
      HapticFeedback.selectionClick();
      Sfx.correct();
      setState(() {
        _solved++;
        _score += 10 + (_remain / _total * 10).round();
      });
    } else {
      HapticFeedback.heavyImpact();
      Sfx.wrong();
      setState(() => _lives--);
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (_lives <= 0) {
      await _finish();
    } else {
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
    final shown = _word.isEmpty
        ? ''
        : [
            for (var i = 0; i < _word.length; i++)
              (i == _hole && _picked == null) ? '_' : _word[i],
          ].join(' ');
    return Scaffold(
      body: SafeArea(
        child: _over
            ? GameOverPanel(
                score: _score,
                best: _best,
                isNewBest: _isNewBest,
                extra: t.p('Words found: $_solved', 'Bulunan kelime: $_solved'),
                onAgain: _start,
                onMenu: _close,
              )
            : Column(
                children: [
                  GameHud(
                    label: t.p('Missing Letter', 'Eksik Harf'),
                    score: _score,
                    lives: _lives,
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: (_remain / _total).clamp(0.0, 1.0).toDouble(),
                        backgroundColor: AppColors.surface,
                        color: _remain / _total < 0.3 ? AppColors.bad : AppColors.accent,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                shown,
                                style: const TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 14,
                              runSpacing: 14,
                              children: [
                                for (final o in _options)
                                  SizedBox(
                                    width: 120,
                                    height: 72,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _optionColor(o),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                      ),
                                      onPressed: () => _answer(o),
                                      child: Text(
                                        o,
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                        ),
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

  Color _optionColor(String o) {
    if (_picked == null) return AppColors.surface;
    if (o == _word[_hole]) return AppColors.good;
    if (o == _picked) return AppColors.bad;
    return AppColors.surface;
  }
}
