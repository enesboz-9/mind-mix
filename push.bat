@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"

set REPO=https://github.com/enesboz-9/color-match-game.git
set BRANCH=main

where git >nul 2>nul
if errorlevel 1 (
  echo [HATA] Git bulunamadi. https://git-scm.com adresinden kurun.
  pause
  exit /b 1
)

REM Platform klasorleri yoksa proje henuz olusturulmamis demektir.
if not exist "android" (
  echo [UYARI] android klasoru yok. Once bu klasorde su komutu calistirin:
  echo         flutter create --project-name mind_mix --org com.bnovative .
  echo         flutter pub get
  echo         dart run flutter_launcher_icons
  echo Sonra bu dosyayi tekrar calistirin.
  pause
  exit /b 1
)

REM Klasor bir git deposu degilse: baslat ve uzak depoya bagla
if not exist ".git" (
  echo [BILGI] Git deposu bulunamadi, olusturuluyor...
  git init
  git branch -M %BRANCH%
  git remote add origin %REPO%
  git fetch origin
  if errorlevel 1 (
    echo [HATA] Depoya baglanilamadi. GitHub girisinizi kontrol edin.
    pause
    exit /b 1
  )
  REM Uzak depoda zaten commit varsa gecmisi koru, dosyalar oldugu gibi kalir
  git rev-parse --verify origin/%BRANCH% >nul 2>nul
  if not errorlevel 1 git reset --soft origin/%BRANCH%
) else (
  git remote get-url origin >nul 2>nul || git remote add origin %REPO%
)

REM CRLF uyarilarini kapat
git config core.autocrlf false
git config core.safecrlf false

git add -A
git status --short

set MSG=Mind Mix: guncelleme
if not "%~1"=="" set MSG=%*

git commit -m "%MSG%"
if errorlevel 1 echo [BILGI] Yeni degisiklik yok ya da commit atlandi.

REM Push oncesi baglanti kontrolu: ag yoksa net bir mesaj ver
git ls-remote --heads origin >nul 2>nul
if errorlevel 1 (
  echo.
  echo [HATA] github.com adresine ulasilamadi. Internet, DNS, VPN veya proxy ayarlarini kontrol edin.
  echo Degisiklikler yerelde commit edildi, kaybolmadi. Baglanti duzelince bu dosyayi tekrar calistirin.
  pause
  exit /b 1
)

git push -u origin %BRANCH%
if errorlevel 1 (
  echo.
  echo [HATA] Push basarisiz. Uzakta yeni degisiklik varsa once: git pull --rebase origin %BRANCH%
  pause
  exit /b 1
)

echo.
echo [TAMAM] GitHub'a gonderildi: %REPO%
pause
