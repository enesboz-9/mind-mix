# Surprise Games

Tek uygulamada 37 hızlı mini oyun. Çevrimdışı, hesapsız, reklamsız.

**Sürpriz düğmesi:** Ana ekrandaki "Sürpriz yap!" düğmesi rastgele bir oyun açar. Oyun içindeki üst barda (zar simgesi) ve oyun sonu panelinde de aynı düğme vardır; oyundan çıkmadan başka rastgele oyuna geçebilirsin.

Oyunlar: Color Match, Odd One Out, Sequence Echo, Math Rush, Lights Out, Tap Rush, Letter Hunt, Number Order, Arrow Rule, Mole Hunt, Chimp Test, Color Words, Pattern Finder, Target Sum, Dot Count, Number Memory, Shape Sort, Read the Clock, Quick Compare, Time Stop, Slide Puzzle, Grid Memory, Reflex, Higher or Lower, Timing Bar, Flip Pairs ve yeni eklenenler:

| Yeni oyun | Kısaca |
|---|---|
| Balloon Pop | Yükselen balonları kaçmadan patlat (3 can) |
| Catch It | Sepetle meyve yakala, bombalardan kaç (3 can) |
| Stack Up | Kayan bloğu tam zamanında bırak, kuleyi yükselt |
| Flap Dot | Dokun, borular arasından geç |
| Dodge Rush | Noktayı sürükle, düşen bloklardan kaç |
| Snake | Klasik yılan (kaydır / ok tuşları) |
| 2048 | Kaydır, aynı sayıları birleştir |
| True or False | Eşitlik doğru mu? (40 sn, 3 can) |
| N-Back | Şekil 1 (sonra 2) önceki ile aynı mı? |
| Emoji Hunt | Izgarada farklı emojiyi bul (30 sn) |
| Tap Storm | 10 saniyede olabildiğince çok dokun |

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
3. `lib/games/registry.dart` içindeki listeye bir `MiniGame(...)` satırı ekle. Sürpriz düğmesi listeyi otomatik kullanır.

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
lib/core/random_game.dart           sürpriz (rastgele oyun) mantığı
lib/core/game_loop.dart             aksiyon oyunları için kare döngüsü
lib/core/game_shell.dart            ortak HUD, düğme, oyun sonu paneli
lib/games/registry.dart             oyun listesi
lib/games/<oyun>/                   her oyun kendi klasöründe
test/color_match_test.dart          Color Match zorluk ve kart üretimi testleri
```

## Not
- Uygulama ikonu ve `ios/.../AppIcon` şimdilik Color Match ikonudur. Yeni bir `assets/logo/icon.png` + `icon_foreground.png` koyup `dart run flutter_launcher_icons` çalıştır.
- Müzik/efektler `tools/generate_audio.py` ile üretilmiş özgün seslerdir.
