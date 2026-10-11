import 'app_settings.dart';
import 'audio_service.dart';

/// Ses efektlerini yalnızca ses açıkken çalar.
class Sfx {
  Sfx._();

  static void correct() {
    if (AppSettings.instance.musicOn) AudioService.instance.playCorrect();
  }

  static void wrong() {
    if (AppSettings.instance.musicOn) AudioService.instance.playWrong();
  }

  static void over() {
    if (AppSettings.instance.musicOn) AudioService.instance.playGameOver();
  }
}
