import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_settings.dart';
import '../../core/game_shell.dart';
import '../../core/score_store.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';

/// Bombayı etkisizleştir: ekrandaki kurala göre doğru teli kes. 40 saniye, 3 can;
/// seri yaptıkça puan artar.
class WireCutScreen extends StatefulWidget {
  const WireCutScreen({super.key});

  @override
  State<WireCutScreen> createState() => _WireCutScreenState();
}

class _WireCutScreenState extends State<WireCutScreen> {
  static const String _id = 'wire_cut';
  static const int _totalSeconds = 40;
  static const int _maxLives = 3;
  static const int _wireCount = 5;
  static const List<Color> _colors = [
    Color(0xFFFF4D4D),
    Color(0xFF4D9DFF),
    Color(0xFF3DDC84),
    Color(0xFFFFC94D),
  ];
  static const List<String> _namesEn = ['red', 'blue', 'green', 'yellow'];
  static const List<String> _namesTr = ['kırmızı', 'mavi', 'yeşil', 'sarı'];

  final math.Random _rnd = math.Random();
  Timer? _timer;
  Timer? _next;

  List<int> _wires = [];
  List<bool> _cut = [];
  int _answer = 0;
  String _ruleEn = '';
  String _ruleTr = '';

  int _left = _totalSeconds;
  int _lives = _maxLives;
  int _score = 0;
  int _streak = 0;
  int _best = 0;
  bool _locked = false;
  bool _over = false;
  bool _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _newPuzzle();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _next?.cancel();
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
    _next?.cancel();
    setState(() {
      _left = _totalSeconds;
      _lives = _maxLives;
      _score = 0;
      _streak = 0;
      _over = false;
      _isNewBest = false;
      _newPuzzle();
    });
    _startTimer();
  }

  /// Kuralı ve doğru tel indeksini üretir; her zaman tek ve geçerli bir cevap çıkar.
  void _newPuzzle() {
    while (true) {
      final wires = List<int>.generate(_wireCount, (_) => _rnd.nextInt(_colors.length));
      final c = wires[_rnd.nextInt(_wireCount)];
      final cn = _namesEn[c];
      final ct = _namesTr[c];
      final type = _rnd.nextInt(5);
      int idx;
      String en;
      String tr;
      switch (type) {
        case 0:
          idx = wires.indexOf(c);
          en = 'Cut the first $cn wire';
          tr = 'İlk $ct teli kes';
          break;
        case 1:
          idx = wires.lastIndexOf(c);
          en = 'Cut the last $cn wire';
          tr = 'Son $ct teli kes';
          break;
        case 2:
          final n = 1 + _rnd.nextInt(_wireCount);
          if (_rnd.nextBool()) {
            idx = n - 1;
            en = 'Cut wire #$n from the left';
            tr = 'Soldan $n. teli kes';
          } else {
            idx = _wireCount - n;
            en = 'Cut wire #$n from the right';
            tr = 'Sağdan $n. teli kes';
          }
          break;
        case 3:
          idx = wires.indexOf(c) + 1;
          en = 'Cut the wire right after the first $cn wire';
          tr = 'İlk $ct telin hemen sağındaki teli kes';
          break;
        default:
          idx = wires.indexWhere((w) => w != c);
          en = 'Cut the first wire that is not $cn';
          tr = '$ct olmayan ilk teli kes';
          break;
      }
      if (idx < 0 || idx >= _wireCount) continue;
      _wires = wires;
      _cut = List<bool>.filled(_wireCount, false);
      _answer = idx;
      _ruleEn = en;
      _ruleTr = tr;
      _locked = false;
      return;
    }
  }

  void _tap(int i) {
    if (_locked || _over) return;
    final ok = i == _answer;
    HapticFeedback.selectionClick();
    setState(() {
      _locked = true;
      _cut[i] = true;
      if (ok) {
        _streak++;
        _score += 10 + math.min(_streak - 1, 10) * 2;
      } else {
        _streak = 0;
        _lives--;
      }
    });
    if (ok) {
      Sfx.correct();
    } else {
      Sfx.wrong();
    }
    _next?.cancel();
    _next = Timer(Duration(milliseconds: ok ? 350 : 900), () {
      if (!mounted || _over) return;
      if (_lives <= 0) {
        _finish();
        return;
      }
      setState(_newPuzzle);
    });
  }

  Future<void> _finish() async {
    if (_over) return;
    _timer?.cancel();
    _next?.cancel();
    setState(() => _over = true);
    Sfx.over();
    final r = await ScoreStore.record(_id, _score);
    if (!mounted) return;
    setState(() {
      _isNewBest = r.isNew;
      _best = r.best;
    });
  }

  Widget _wire(int i) {
    final cut = _cut[i];
    final showAnswer = _locked && i == _answer && !cut;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(i),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 34,
            decoration: BoxDecoration(
              color: _colors[_wires[i]].withAlpha(cut ? 60 : 255),
              borderRadius: BorderRadius.circular(17),
              border: showAnswer ? Border.all(color: Colors.white, width: 3) : null,
            ),
            child: cut
                ? const Center(child: Icon(Icons.content_cut_rounded, color: Colors.white))
                : null,
          ),
        ),
      ),
    );
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
                    label: t.p('Defuse', 'Etkisizleştir'),
                    score: _score,
                    lives: _lives,
                    maxLives: _maxLives,
                    timeText: '${_left}s',
                    onClose: _close,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Text(
                      t.p(_ruleEn, _ruleTr),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                        child: Row(
                          children: List<Widget>.generate(_wireCount, _wire),
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
