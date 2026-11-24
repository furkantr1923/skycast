#!/usr/bin/env bash
# Android emülatöründe kurulum + açılış testi ve gerçek veriyle ekran görüntüleri.
# Kullanım: android_e2e.sh <release.apk> <capture.apk> <çıktı klasörü>
set -u
APK="$1"; CAP_APK="$2"; OUT="$3"; PKG=com.furkan.skycast
mkdir -p "$OUT"
REPORT="$OUT/android_e2e.txt"
log(){ echo "$*" | tee -a "$REPORT"; }

adb wait-for-device
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

log "== 1) Sürüm APK kurulumu"
if adb install -r "$APK" >> "$REPORT" 2>&1; then log "OK   APK kuruldu"; else log "FAIL APK kurulamadı"; fi
adb shell dumpsys package $PKG | grep -E "versionName|requested permissions|android.permission" | head -12 >> "$REPORT"

log "== 2) Konum izni akışı: önce izin VERİLMEDEN açılış"
adb shell am start -W -n $PKG/.MainActivity >> "$REPORT" 2>&1
sleep 12
adb exec-out screencap -p > "$OUT/a01_izin_istegi.png"
if adb shell pidof $PKG > /dev/null; then log "OK   uygulama çalışıyor (izin penceresi)"; else log "FAIL uygulama kapandı"; fi
adb shell am force-stop $PKG

log "== 3) İzin verilmiş + GPS konumu (İstanbul) ile açılış"
adb emu geo fix 28.9784 41.0082 || true
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION
adb shell pm grant $PKG android.permission.ACCESS_COARSE_LOCATION
adb shell appops set $PKG android:mock_location allow >/dev/null 2>&1 || true
START=$(date +%s%3N)
adb shell am start -W -n $PKG/.MainActivity | tee -a "$REPORT"
sleep 25
adb exec-out screencap -p > "$OUT/a02_gps_panel.png"
if adb shell pidof $PKG > /dev/null; then log "OK   GPS ile açılış: uygulama çalışıyor"; else log "FAIL GPS açılışında uygulama kapandı"; fi
adb shell dumpsys meminfo $PKG | grep -E "TOTAL PSS|TOTAL RSS|TOTAL:" | head -3 | sed 's/^/BELLEK /' | tee -a "$REPORT"
adb shell top -b -n 1 | grep $PKG | head -1 | sed 's/^/CPU /' | tee -a "$REPORT"
adb logcat -d -s flutter:V AndroidRuntime:E | tail -40 >> "$REPORT"
adb shell am force-stop $PKG
adb uninstall $PKG >/dev/null 2>&1

log "== 4) Öz-sınama APK'sı: tüm ekranlar gerçek veriyle"
adb install -r "$CAP_APK" >> "$REPORT" 2>&1
adb shell pm grant $PKG android.permission.ACCESS_FINE_LOCATION
adb logcat -c
adb shell am start -n $PKG/.MainActivity >/dev/null
seen=""
end=$(( $(date +%s) + 420 ))
while [ "$(date +%s)" -lt "$end" ]; do
  lines=$(adb logcat -d -s flutter:I | grep -o "SKYCAST_CAPTURE step=[0-9A-Za-z_]*\|SKYCAST_CAPTURE done" || true)
  for step in $(echo "$lines" | grep -o "step=[0-9A-Za-z_]*" | cut -d= -f2); do
    case " $seen " in *" $step "*) ;; *)
      sleep 0.6
      adb exec-out screencap -p > "$OUT/$step.png"
      seen="$seen $step"; log "EKRAN $step";;
    esac
  done
  if echo "$lines" | grep -q "SKYCAST_CAPTURE done"; then break; fi
  sleep 0.7
done
adb logcat -d -s flutter:I | grep "SKYCAST_SELFTEST" | sed 's/.*SKYCAST_SELFTEST //' > "$OUT/android_selftest.txt"
cat "$OUT/android_selftest.txt" >> "$REPORT"
if adb shell pidof $PKG > /dev/null; then log "OK   öz-sınama sonunda uygulama hâlâ çalışıyor"; else log "FAIL uygulama öz-sınama sırasında kapandı"; fi
adb logcat -d -s AndroidRuntime:E | tail -30 >> "$REPORT"
exit 0
