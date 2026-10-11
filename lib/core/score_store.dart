import 'package:shared_preferences/shared_preferences.dart';

/// Oyun başına en yüksek skor. Her oyun kendi kimliği (id) ile saklar.
class ScoreStore {
  ScoreStore._();

  static String _key(String id) => 'best_$id';

  static Future<int> best(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key(id)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Skoru kaydeder; yeni rekorsa true döner.
  static Future<bool> submit(String id, int score) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getInt(_key(id)) ?? 0;
      if (score > old) {
        await prefs.setInt(_key(id), score);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Skoru kaydeder ve (yeni rekor mu, güncel en iyi) bilgisini döndürür.
  static Future<({bool isNew, int best})> record(String id, int score) async {
    final old = await best(id);
    final isNew = await submit(id, score);
    return (isNew: isNew, best: isNew ? score : old);
  }
}
