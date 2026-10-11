import 'package:flutter/scheduler.dart';

/// Aksiyon oyunları için basit oyun döngüsü: her karede geçen süreyi
/// saniye cinsinden ([dt]) bildirir. Çok uzun karelerde dt 0.05 sn'ye kırpılır.
class GameLoop {
  GameLoop(TickerProvider vsync, this.onTick) {
    _ticker = vsync.createTicker(_handle);
  }

  final void Function(double dt) onTick;
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  void start() {
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
  }

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void dispose() => _ticker.dispose();

  void _handle(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000.0;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > 0.05) dt = 0.05;
    onTick(dt);
  }
}
