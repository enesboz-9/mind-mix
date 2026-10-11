import 'package:audioplayers/audioplayers.dart';

/// Müzik ve ses efektleri. Tüm sesler `tools/generate_audio.py` ile üretilmiş
/// özgün seslerdir, telif sorunu yoktur.
///
/// Tarayıcılar kullanıcı dokunuşundan önce ses çalmaya izin vermediği için
/// müzik ilk olarak "Oyna" tuşuna basılınca başlatılır.
class AudioService {
  AudioService._();
  static final AudioService instance = AudioService._();

  AudioPlayer? _music;
  AudioPlayer? _sfx;
  bool _musicLoaded = false;

  bool get hasStarted => _musicLoaded;

  Future<void> playMusic() async {
    try {
      final p = _music ??= AudioPlayer();
      if (!_musicLoaded) {
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0.35);
        await p.play(AssetSource('audio/music.wav'));
        _musicLoaded = true;
      } else {
        await p.resume();
      }
    } catch (_) {
      // Ses çalınamazsa oyun sessiz devam etsin.
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _music?.pause();
    } catch (_) {}
  }

  Future<void> _playSfx(String file, {double volume = 0.8}) async {
    try {
      final p = _sfx ??= AudioPlayer();
      await p.stop();
      await p.play(AssetSource('audio/$file'), volume: volume);
    } catch (_) {}
  }

  Future<void> playCorrect() => _playSfx('correct.wav');
  Future<void> playWrong() => _playSfx('wrong.wav');
  Future<void> playGameOver() => _playSfx('over.wav');
}
