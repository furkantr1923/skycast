# Kurulum ve derleme

## Hazır dosyalarla kurulum

| Platform | Dosya | Not |
|---|---|---|
| Windows 10/11 (64 bit) | `SKYCAST-Setup-1.0.0.exe` | Kurulum sihirbazı (Türkçe), Başlat menüsü ve isteğe bağlı masaüstü kısayolu. Yönetici izni gerekmez. |
| Windows (kurulumsuz) | `SKYCAST-Windows-1.0.0-portable.zip` | Zip'i açın, `SKYCAST.exe`'yi çalıştırın. VC++ DLL'leri klasörün içindedir. |
| Android 7.0+ | `SKYCAST-1.0.0.apk` | "Bilinmeyen kaynaklardan yüklemeye" izin verip kurun. |

Windows kurulum dosyası kod imzalı değildir; SmartScreen "Windows bilgisayarınızı
korudu" derse **Ek bilgi → Yine de çalıştır** seçin.

## Kaynaktan derleme

Gereksinimler: Flutter **3.50.1** (Dart 3.14), Windows için Visual Studio 2022
"Desktop development with C++", Android için Android SDK + JDK 17.

```bash
flutter pub get
flutter test
flutter run                       # bağlı cihaz/emülatör
flutter build apk --release       # Android
flutter build windows --release   # Windows (Windows makinesinde)
```

Windows kurulum dosyası için [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
iscc /DAppVersion=1.0.0 installer\skycast.iss   # çıktı: dist\SKYCAST-Setup-1.0.0.exe
```

## Öz-sınama modu

```powershell
SKYCAST.exe --capture=C:\skycast-test
```

Uygulama İstanbul için gerçek verileri indirir, tüm ekranları gezip PNG kaydeder,
her veri kaynağını sınar, `selftest.txt` yazar ve kapanır. Android'de aynı mod
`--dart-define=SKYCAST_CAPTURE=true` ile derlenen APK'da çalışır.

## Kalıcı Android imza anahtarı

CI, `ANDROID_KEYSTORE_BASE64` ve `ANDROID_KEYSTORE_PASSWORD` gizli değişkenleri
tanımlıysa APK'yı bu anahtarla imzalar. Tanımlı değilse her derlemede **geçici**
bir anahtar üretilir (APK yine kurulur, ancak sonraki sürüm üstüne güncelleme
yerine kaldırıp yeniden kurmak gerekir). Kalıcı anahtar için:

```bash
keytool -genkeypair -keystore skycast.jks -alias skycast -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 skycast.jks   # çıktıyı ANDROID_KEYSTORE_BASE64 olarak ekleyin
```

GitHub → Settings → Secrets and variables → Actions → New repository secret.
Anahtar dosyası ve şifresi **asla** depoya eklenmez (`.gitignore`'da).

## CI (GitHub Actions)

`.github/workflows/build.yml` her `main` gönderiminde:

1. `flutter analyze` + birim/arayüz testleri
2. Windows: derleme → gerçek uygulamayla öz-sınama ve ekran görüntüleri → Setup.exe + taşınabilir zip
3. Android: imzalı APK
4. Android emülatörü (API 34): APK kurulumu, izin akışı, GPS ile açılış, bellek/CPU ölçümü, tüm ekranların görüntüsü
5. Çıktılar `builds` dalına; `v*` etiketlerinde GitHub Release'e eklenir.
