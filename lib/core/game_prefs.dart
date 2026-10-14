import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favoriler, son oynananlar ve "oynandı" bilgisi. Cihazda saklanır.
class GamePrefs extends ChangeNotifier {
  GamePrefs._();
  static final GamePrefs instance = GamePrefs._();

  static const String _favKey = 'fav_games';
  static const String _recentKey = 'recent_games';
  static const String _playedKey = 'played_games';
  static const int _maxRecents = 8;

  final Set<String> favorites = <String>{};
  final Set<String> played = <String>{};

  /// En yeni başta.
  final List<String> recents = <String>[];

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      favorites
        ..clear()
        ..addAll(prefs.getStringList(_favKey) ?? const <String>[]);
      played
        ..clear()
        ..addAll(prefs.getStringList(_playedKey) ?? const <String>[]);
      recents
        ..clear()
        ..addAll(prefs.getStringList(_recentKey) ?? const <String>[]);
    } catch (_) {}
  }

  bool isFavorite(String id) => favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_favKey, favorites.toList());
    } catch (_) {}
  }

  /// Oyun açıldığında çağrılır: "oynandı" işaretler ve son oynananlara ekler.
  Future<void> markPlayed(String id) async {
    played.add(id);
    recents
      ..remove(id)
      ..insert(0, id);
    if (recents.length > _maxRecents) {
      recents.removeRange(_maxRecents, recents.length);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_playedKey, played.toList());
      await prefs.setStringList(_recentKey, recents);
    } catch (_) {}
  }
}
