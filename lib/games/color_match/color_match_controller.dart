import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/score_store.dart';
import '../../core/sfx.dart';
import 'choice_builder.dart';
import 'color_utils.dart';
import 'difficulty.dart';

enum GamePhase { show, choose, reveal, over }

class ColorMatchController extends ChangeNotifier {
  ColorMatchController({ChoiceBuilder? builder}) : _builder = builder ?? ChoiceBuilder();

  static const String gameId = 'color_match';
  static const int viewSeconds = 10;
  static const int startLives = 3;

  final ChoiceBuilder _builder;

  GamePhase phase = GamePhase.show;
  int level = 1;
  int lives = startLives;
  int score = 0;
  int streak = 0;
  int bestScore = 0;
  bool isNewBest = false;

  late Round round;
  late Difficulty difficulty;

  int? selectedIndex;
  int lastGain = 0;
  bool lastCorrect = false;

  /// Hedef renk görünme süresinden kalan milisaniye.
  int remainingMs = viewSeconds * 1000;

  Timer? _viewTimer;
  Timer? _revealTimer;
  bool _disposed = false;

  Future<void> init() async {
    bestScore = await ScoreStore.best(gameId);
    _safeNotify();
  }

  void start() {
    _cancelTimers();
    level = 1;
    lives = startLives;
    score = 0;
    streak = 0;
    isNewBest = false;
    _startRound();
  }

  void _startRound() {
    difficulty = Difficulty.forLevel(level);
    round = _builder.buildWithRetry(
      cardCount: difficulty.cardCount,
      deltaE: difficulty.deltaE,
    );
    selectedIndex = null;
    remainingMs = viewSeconds * 1000;
    phase = GamePhase.show;
    _safeNotify();

    _viewTimer?.cancel();
    _viewTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      remainingMs -= 100;
      if (remainingMs <= 0) {
        remainingMs = 0;
        t.cancel();
        _goChoose();
      } else {
        _safeNotify();
      }
    });
  }

  /// Oyuncu "Hazırım" der; kalan süre bonus puana dönüşür.
  void skipView() {
    if (phase != GamePhase.show) return;
    _viewTimer?.cancel();
    _goChoose();
  }

  void _goChoose() {
    phase = GamePhase.choose;
    _safeNotify();
  }

  void pick(int index) {
    if (phase != GamePhase.choose) return;
    _revealTimer?.cancel();
    selectedIndex = index;
    lastCorrect = index == round.correctIndex;

    if (lastCorrect) {
      streak++;
      final skipBonus = (remainingMs / 1000).floor() * 5;
      final streakBonus = (streak - 1) * 10;
      lastGain = 100 + (level - 1) * 10 + skipBonus + streakBonus;
      score += lastGain;
      HapticFeedback.lightImpact();
      Sfx.correct();
    } else {
      streak = 0;
      lastGain = 0;
      lives--;
      HapticFeedback.heavyImpact();
      Sfx.wrong();
    }

    phase = GamePhase.reveal;
    _safeNotify();

    _revealTimer = Timer(const Duration(milliseconds: 1400), () async {
      if (lives <= 0) {
        await _finish();
      } else {
        if (lastCorrect) level++;
        _startRound();
      }
    });
  }

  Future<void> _finish() async {
    isNewBest = await ScoreStore.submit(gameId, score);
    if (isNewBest) bestScore = score;
    phase = GamePhase.over;
    _safeNotify();
    Sfx.over();
  }

  Rgb get target => round.target;

  void _cancelTimers() {
    _viewTimer?.cancel();
    _revealTimer?.cancel();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }
}
