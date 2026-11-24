# Veri sağlayıcıları

SKYCAST yalnızca **ücretsiz, anahtar gerektirmeyen** kaynaklar kullanır. Ücretli
API, deneme sürümü, kayıt ya da ödeme yöntemi isteyen hiçbir servis yoktur.
"Ücretsiz erişim" ile "açık kaynak/açık veri" aynı şey değildir; her kaynağın
lisansı aşağıda ayrı ayrı belirtilmiştir.

Tüm sağlayıcılar `lib/data/providers/` altında birbirinden bağımsız sınıflardır
ve `WeatherRepository` üzerinden kullanılır. Bir kaynak çökerse yalnızca ilgili
özellik "kullanılamıyor" durumuna geçer; uygulamanın geri kalanı çalışır.

| Özellik | Kaynak | Erişim | Lisans / koşul | Sınırlar | Atıf |
|---|---|---|---|---|---|
| Anlık durum, saatlik, 15 gün | [Open-Meteo Forecast](https://open-meteo.com/en/docs) | Anahtarsız | Veri CC BY 4.0; ücretsiz katman **ticari olmayan** kullanım içindir | Günde 10.000, saatte 5.000, dakikada 600 çağrı; en fazla 16 gün | "Open-Meteo.com" |
| Harita ızgaraları (yağış, bulut, sıcaklık, rüzgâr, basınç) | Open-Meteo (çoklu konum isteği) | Anahtarsız | CC BY 4.0 | Her nokta bir çağrı sayılır → ızgara 9×7, 15 dk önbellek, 0,5° yuvarlama | "Open-Meteo.com" |
| Hava kalitesi (yalnızca AQI) | [Open-Meteo Air Quality](https://open-meteo.com/en/docs/air-quality-api) (CAMS) | Anahtarsız | CAMS verisi, Copernicus lisansı | Saatlik model | "CAMS / Open-Meteo" |
| Şehir arama | [Open-Meteo Geocoding](https://open-meteo.com/en/docs/geocoding-api) (GeoNames) | Anahtarsız | CC BY 4.0 | — | "GeoNames" |
| Koordinat → yer adı | [OSM Nominatim](https://nominatim.org/release-docs/latest/api/Reverse/) | Anahtarsız | ODbL; [kullanım politikası](https://operations.osmfoundation.org/policies/nominatim/) | Saniyede en fazla 1 istek, tanımlayıcı User-Agent zorunlu (uygulamada uygulanıyor) | "© OpenStreetMap" |
| Yağış radarı | [RainViewer Weather Maps API](https://www.rainviewer.com/api.html) | Anahtarsız | Kişisel/eğitim amaçlı ücretsiz; ticari kullanım için izin gerekir | 2026'dan itibaren ücretsiz katmanda yalnızca **son ~2 saatlik geçmiş** kareler, **en fazla zoom 7**, **ileri tahmin (nowcast) yok** | "RainViewer.com" |
| Uydu (Meteosat / MTG) | [EUMETSAT EUMETView WMS](https://view.eumetsat.int) | Anahtarsız | EUMETSAT veri politikası, atıf zorunlu | Kapsama: Avrupa, Afrika, Orta Doğu, Atlantik; 10/15 dk adım; 2020'den beri arşiv | "© EUMETSAT" |
| Uydu (günlük gerçek renk) | [NASA GIBS](https://nasa-gibs.github.io/gibs-api-docs/) (MODIS Terra) | Anahtarsız | NASA açık veri politikası | Günde bir mozaik | "NASA EOSDIS GIBS" |
| Resmî uyarılar | [MeteoAlarm](https://meteoalarm.org) (EUMETNET) | Anahtarsız | Ulusal servislerin resmî CAP uyarıları | **Türkiye akışta yok (HTTP 404)**; Avrupa'nın 38 ülkesi | "MeteoAlarm" |
| Altlık harita | [CARTO Basemaps](https://github.com/CartoDB/basemap-styles) (OSM) | Anahtarsız | Ticari olmayan kullanımda ücretsiz; OSM ODbL | Ayda 75.000 görüntüleme | "© OpenStreetMap © CARTO" |

## Gerçek veriyle doğrulama

Her derlemede CI, derlenmiş uygulamayı Windows'ta ve Android emülatöründe
`--capture` / `SKYCAST_CAPTURE` öz-sınama modunda çalıştırır. Uygulama tüm
kaynaklara gerçekten bağlanır, sonuçları `selftest.txt` / `android_selftest.txt`
olarak yazar ve her ekranın görüntüsünü alır. Sonuçlar `builds` dalındadır.

## Bilinçli sınırlamalar

- **İleri radar tahmini yok.** Kaynak (RainViewer) ücretsiz katmanda nowcast
  karesi göndermiyor; SKYCAST tahmin karesi **üretmez/simüle etmez**. Kaynak bir
  gün tahmin karesi gönderirse kod onu otomatik olarak "TAHMİN" etiketiyle gösterir.
- **Radar canlı değildir.** Kareler gerçek tarama zamanıyla ve "kaç dakika önce"
  bilgisiyle gösterilir; "canlı değil" etiketi her zaman görünür.
- **Radar en fazla zoom 7.** Daha yakın görünümde kaynak görüntüsü büyütülür.
- **Türkiye için resmî uyarı yok.** MGM'nin açık ve lisansı net bir uyarı API'si
  bulunamadı, MeteoAlarm da Türkiye'yi kapsamıyor. Uygulama bunu açıkça yazar.
  Bunun yerine "Uygulama göstergesi · resmî uyarı değil" etiketli, tahmin
  eşiklerinden hesaplanan göstergeler sunulur.
- **Sıcaklık/rüzgâr/basınç/bulut haritaları model verisidir**, gözlem değildir.
  Ücretsiz ve anahtarsız hazır döşeme (tile) katmanı bulunmadığı için bu katmanlar
  Open-Meteo'nun gerçek ızgara değerlerinden cihazda çizilir.
- **15 günlük tahmin**: Open-Meteo 16 gün veriyor; ilk 15 gün gösterilir.
  1–3. gün yüksek, 4–7. gün orta, 8–15. gün düşük güvenilirlik etiketi taşır.
- Ücretsiz katmanların çoğu **ticari olmayan** kullanım içindir. Uygulama
  ticari olarak dağıtılacaksa Open-Meteo, RainViewer ve CARTO koşulları yeniden
  değerlendirilmelidir.
