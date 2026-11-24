import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:skycast/data/providers/open_meteo_air.dart';
import 'package:skycast/data/providers/open_meteo_forecast.dart';
import 'package:skycast/data/providers/radar.dart';
import 'package:skycast/data/providers/satellite.dart';
import 'package:skycast/domain/alert.dart';
import 'package:skycast/domain/alert_engine.dart';
import 'package:skycast/domain/aqi.dart';
import 'package:skycast/domain/reliability.dart';
import 'package:skycast/domain/weather_code.dart';
import 'package:skycast/domain/wind.dart';

import 'fixtures.dart';

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  group('Open-Meteo ayrıştırma', () {
    test('16 gün, saatlik seri ve konum saati doğru okunur', () {
      final f = OpenMeteoForecastProvider.parse(forecastJson());
      expect(f.daily.length, 16);
      expect(f.hourly.length, 16 * 24);
      expect(f.clock.timezone, 'Europe/Istanbul');
      // Gün başı konum saatiyle 00:00 olmalı (cihaz saat diliminden bağımsız).
      expect(f.daily.first.date, DateTime.utc(2026, 11, 24));
      expect(f.hourly.first.time.hour, 0);
      expect(f.current.time.hour, 14);
      expect(f.daily.first.sunrise!.hour, 7);
      expect(f.daily.first.sunrise!.minute, 20);
      expect(f.current.temperature, 12.4);
      // Anlık yanıtta olmayan değerler içinde bulunulan saatten gelir.
      expect(f.current.uvIndex, 2.5);
      expect(f.current.visibility, 24000);
      expect(f.daily.first.humidityMean, 70);
    });

    test('Eksik değerler null kalır, uydurulmaz', () {
      final j = forecastJson();
      (j['hourly'] as Map)['uv_index'] = List<num?>.filled(16 * 24, null);
      (j['current'] as Map).remove('wind_gusts_10m');
      final f = OpenMeteoForecastProvider.parse(j);
      expect(f.current.uvIndex, isNull);
      expect(f.current.windGusts, isNull);
    });

    test('Tamamen boş günler listeden çıkarılır', () {
      final j = forecastJson();
      final d = j['daily'] as Map<String, dynamic>;
      for (final k in ['temperature_2m_max', 'temperature_2m_min', 'weather_code']) {
        (d[k] as List)[15] = null;
      }
      final f = OpenMeteoForecastProvider.parse(j);
      expect(f.daily.length, 15);
    });

    test('Bozuk yanıt hata verir', () {
      expect(() => OpenMeteoForecastProvider.parse({'latitude': 1}), throwsA(anything));
    });

    test('AQI ayrıştırma', () {
      final a = OpenMeteoAirProvider.parse({
        'utc_offset_seconds': 10800,
        'timezone': 'Europe/Istanbul',
        'current': {'time': 1795539600, 'european_aqi': 71, 'us_aqi': 56},
      });
      expect(a.europeanAqi, 71);
      expect(Aqi.level(71, AqiScale.european).label, 'Kötü');
      expect(Aqi.level(56, AqiScale.us).label, 'Orta');
    });
  });

  group('Rüzgâr', () {
    test('Beaufort eşikleri', () {
      expect(Wind.beaufort(0), 0);
      expect(Wind.beaufort(5), 1);
      expect(Wind.beaufort(19.9), 3);
      expect(Wind.beaufort(40), 6);
      expect(Wind.beaufort(120), 12);
      expect(Wind.beaufortName(8), 'Fırtına');
    });
    test('Yön adları', () {
      expect(Wind.direction(0), 'K');
      expect(Wind.direction(45), 'KD');
      expect(Wind.direction(180), 'G');
      expect(Wind.direction(359), 'K');
      expect(Wind.directionName(270), 'Batı');
    });
  });

  test('Hava kodları Türkçe', () {
    expect(WeatherCode.describe(0), 'Açık');
    expect(WeatherCode.describe(95), 'Gök gürültülü sağanak');
    expect(WeatherCode.kind(99), SkyKind.hail);
  });

  test('Tahmin güvenilirliği', () {
    expect(ReliabilityX.forDay(0), Reliability.high);
    expect(ReliabilityX.forDay(5), Reliability.medium);
    expect(ReliabilityX.forDay(14), Reliability.low);
  });

  group('Uygulama göstergeleri', () {
    test('Sakin havada gösterge yok', () {
      final f = OpenMeteoForecastProvider.parse(forecastJson());
      expect(const AlertEngine().evaluate(f, 'İstanbul'), isEmpty);
    });

    test('Kuvvetli yağış, fırtına, dolu ve don eşikleri; hepsi resmî değil', () {
      final f = OpenMeteoForecastProvider.parse(forecastJson(rainDay0: 55, gust0: 82, code0: 96, tMin0: -2));
      final a = const AlertEngine().evaluate(f, 'İstanbul');
      final types = a.map((e) => e.type).toSet();
      expect(types, containsAll([AlertType.heavyRain, AlertType.flood, AlertType.storm, AlertType.hail, AlertType.lightning, AlertType.frost, AlertType.ice]));
      expect(a.every((e) => e.origin == AlertOrigin.indicator), isTrue);
      expect(a.first.severity.index, greaterThanOrEqualTo(AlertSeverity.orange.index));
      expect(a.first.originLabel, contains('resmî uyarı değil'));
    });
  });

  group('Radar', () {
    test('Tahmin karesi yoksa uydurulmaz', () {
      final s = RainViewerProvider.parse({
        'host': 'https://tilecache.rainviewer.com',
        'generated': 1795539921,
        'radar': {
          'past': [
            {'time': 1795532400, 'path': '/v2/radar/a'},
            {'time': 1795533000, 'path': '/v2/radar/b'},
          ],
          'nowcast': [],
        },
        'satellite': {'infrared': []},
      });
      expect(s.frames.length, 2);
      expect(s.hasForecast, isFalse);
      expect(s.latestObserved!.tileUrl, 'https://tilecache.rainviewer.com/v2/radar/b/256/{z}/{x}/{y}/2/1_1.png');
    });
  });

  test('Uydu son görüntü zamanı (GetCapabilities)', () {
    const xml = '<Layer><Name>ir105_hrfi</Name><Dimension name="time" default="2026-11-24T16:40:00Z" units="ISO8601">'
        '2024-09-23T00:00:00.000Z/2026-11-24T16:40:00.000Z/PT10M</Dimension></Layer>';
    expect(SatelliteProvider.parseLatest(xml), DateTime.utc(2026, 11, 24, 16, 40));
    const noDefault = '<Dimension name="time" units="ISO8601">2024-09-23T00:00:00Z/2026-11-24T16:30:00Z/PT10M</Dimension>';
    expect(SatelliteProvider.parseLatest(noDefault), DateTime.utc(2026, 11, 24, 16, 30));
  });
}
