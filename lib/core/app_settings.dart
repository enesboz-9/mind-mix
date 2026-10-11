import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_service.dart';
import 'l10n.dart';

/// Dil ve ses ayarları. Tercihler cihazda saklanır.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const String _langKey = 'lang';
  static const String _musicKey = 'music_on';

  /// 'en' (varsayılan) veya 'tr'.
  String lang = 'en';
  bool musicOn = true;

  AppStrings get t => AppStrings(lang == 'tr');

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lang = prefs.getString(_langKey) == 'tr' ? 'tr' : 'en';
      musicOn = prefs.getBool(_musicKey) ?? true;
    } catch (_) {}
  }

  Future<void> setLang(String value) async {
    lang = value == 'tr' ? 'tr' : 'en';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langKey, lang);
    } catch (_) {}
  }

  Future<void> setMusic(bool on) async {
    musicOn = on;
    notifyListeners();
    if (on) {
      await AudioService.instance.playMusic();
    } else {
      await AudioService.instance.pauseMusic();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicKey, on);
    } catch (_) {}
  }
}

/// Ayarlar değişince alt widget'ları yeniden çizer.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({super.key, required AppSettings settings, required super.child})
      : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope bulunamadı');
    return scope!.notifier!;
  }
}
