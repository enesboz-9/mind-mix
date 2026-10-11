# Mind Mix

Tek uygulamada 6 hızlı zeka oyunu. Çevrimdışı, hesapsız, reklamsız.

| Oyun | Kısaca |
|---|---|
| Color Match | Rengi aklında tut, çok benzeyen kartlar arasından aynısını bul (3 can, sonsuz) |
| Odd One Out | Izgarada biraz farklı tonu bul (30 sn, yanlış = -3 sn) |
| Sequence Echo | Yanan sırayı izle, tekrar et (yanlış = oyun biter) |
| Math Rush | Hızlı işlemler (45 sn, 3 can) |
| Lights Out | Işıkları söndür, bölümler gittikçe büyür (hepsi çözülebilir) |
| Tap Rush | Beliren daireye süresi dolmadan dokun (3 can, hızlanır) |

## Kurulum
```bash
flutter pub get
dart run flutter_launcher_icons   # assets/logo/icon.png'den ikon üretir
flutter analyze
flutter test
flutter run
```
`android/` ve `ios/` klasörleri hazır geliyor (paket: `com.bnovative.mind_mix`, iOS bundle: `com.bnovative.mindMix`). iOS `Info.plist` içinde `ITSAppUsesNonExemptEncryption=false` zaten ekli.

## Yeni oyun eklemek
1. `lib/games/<oyun_adi>/<oyun_adi>_screen.dart` oluştur (ortak parçalar için `lib/core/game_shell.dart`: `GameHud`, `GameOverPanel`, `PillButton`).
2. Skoru `ScoreStore.record('<oyun_adi>', skor)` ile kaydet.
3. `lib/games/registry.dart` içindeki listeye bir `MiniGame(...)` satırı ekle.

## Dosya yapısı
```
lib/main.dart                       uygulama girişi
lib/home/home_screen.dart           oyun kartları (ana menü)
lib/core/theme.dart                 renkler ve tema
lib/core/l10n.dart                  EN / TR ortak metinler (oyunlarda t.p('en','tr'))
lib/core/app_settings.dart          dil + müzik ayarı (kayıtlı)
lib/core/audio_service.dart         müzik ve ses efektleri
lib/core/sfx.dart                   ses açıksa efekt çal
lib/core/score_store.dart           oyun başına en yüksek skor
lib/core/mini_game.dart             oyun tanımı
lib/core/game_shell.dart            ortak HUD, düğme, oyun sonu paneli
lib/games/registry.dart             oyun listesi
lib/games/<oyun>/                   her oyun kendi klasöründe
test/color_match_test.dart          Color Match zorluk ve kart üretimi testleri
```

## Not
- Uygulama ikonu ve `ios/.../AppIcon` şimdilik Color Match ikonudur. Yeni bir `assets/logo/icon.png` + `icon_foreground.png` koyup `dart run flutter_launcher_icons` çalıştır.
- Müzik/efektler `tools/generate_audio.py` ile üretilmiş özgün seslerdir.
