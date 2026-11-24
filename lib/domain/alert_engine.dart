import '../core/format.dart';
import 'alert.dart';
import 'weather.dart';
import 'weather_code.dart';

/// Tahmin verisinden "uygulama göstergesi" üretir.
///
/// Bunlar RESMÎ UYARI DEĞİLDİR: yalnızca model tahminindeki değerlerin
/// belirli eşikleri aştığını gösterir ve arayüzde her zaman böyle etiketlenir.
/// Güvenilirlik için yalnızca önümüzdeki 3 gün değerlendirilir.
class AlertEngine {
  const AlertEngine();

  static const horizonDays = 3;

  List<WeatherAlert> evaluate(Forecast f, String placeName) {
    final out = <WeatherAlert>[];
    final days = f.daily.take(horizonDays).toList();

    for (final d in days) {
      final date = d.date;
      final dayLabel = '${Fmt.dayLong(date)}, ${Fmt.dayMonth(date)}';
      final dayEnd = date.add(const Duration(hours: 23, minutes: 59));
      final hours = f.hourly.where((h) => h.time.year == date.year && h.time.month == date.month && h.time.day == date.day).toList();
      final codes = hours.map((h) => h.weatherCode).toSet()..add(d.weatherCode);
      final maxHourlyRain = hours.fold<double>(0, (m, h) => (h.precipitation ?? 0) > m ? h.precipitation! : m);

      void add(AlertType type, AlertSeverity sev, String desc) {
        out.add(WeatherAlert(
          id: 'ind:${placeName.toLowerCase()}:${type.name}:${date.toIso8601String().substring(0, 10)}',
          type: type,
          severity: sev,
          origin: AlertOrigin.indicator,
          title: type.label,
          description: '$dayLabel · $desc',
          placeName: placeName,
          start: date,
          end: dayEnd,
          source: 'SKYCAST eşik hesabı (Open-Meteo tahmini)',
        ));
      }

      // Kuvvetli yağış
      final p = d.precipitationSum ?? 0;
      if (p >= 70) {
        add(AlertType.heavyRain, AlertSeverity.red, 'Günlük toplam yağış tahmini ${Fmt.mm(p)}.');
      } else if (p >= 40) {
        add(AlertType.heavyRain, AlertSeverity.orange, 'Günlük toplam yağış tahmini ${Fmt.mm(p)}.');
      } else if (p >= 20 || maxHourlyRain >= 10) {
        add(AlertType.heavyRain, AlertSeverity.yellow,
            'Günlük ${Fmt.mm(p)}, saatlik en fazla ${Fmt.mm(maxHourlyRain)} yağış bekleniyor.');
      }

      // Sel riski (yağış toplamına dayalı gösterge)
      if (p >= 80) {
        add(AlertType.flood, AlertSeverity.red, 'Çok yüksek yağış toplamı (${Fmt.mm(p)}) su baskını riskini artırır.');
      } else if (p >= 50) {
        add(AlertType.flood, AlertSeverity.orange, 'Yüksek yağış toplamı (${Fmt.mm(p)}) su baskını riskini artırır.');
      }

      // Yoğun kar (Open-Meteo kar yağışı cm verir)
      final s = d.snowfallSum ?? 0;
      if (s >= 30) {
        add(AlertType.heavySnow, AlertSeverity.red, 'Günlük kar yağışı tahmini ${Fmt.cm(s)}.');
      } else if (s >= 15) {
        add(AlertType.heavySnow, AlertSeverity.orange, 'Günlük kar yağışı tahmini ${Fmt.cm(s)}.');
      } else if (s >= 5) {
        add(AlertType.heavySnow, AlertSeverity.yellow, 'Günlük kar yağışı tahmini ${Fmt.cm(s)}.');
      }

      // Rüzgâr / fırtına (hamle)
      final g = d.windGustsMax ?? 0;
      if (g >= 100) {
        add(AlertType.storm, AlertSeverity.red, 'Rüzgâr hamlesi ${Fmt.wind(g)} değerine ulaşabilir.');
      } else if (g >= 75) {
        add(AlertType.storm, AlertSeverity.orange, 'Rüzgâr hamlesi ${Fmt.wind(g)} değerine ulaşabilir.');
      } else if (g >= 50) {
        add(AlertType.strongWind, AlertSeverity.yellow, 'Rüzgâr hamlesi ${Fmt.wind(g)} değerine ulaşabilir.');
      }

      // Gök gürültüsü, yıldırım, dolu
      if (codes.any(WeatherCode.isHail)) {
        add(AlertType.hail, AlertSeverity.orange, 'Modelde dolu ile gök gürültülü fırtına görünüyor.');
      }
      if (codes.any(WeatherCode.isThunder)) {
        add(AlertType.lightning, AlertSeverity.yellow, 'Gök gürültülü sağanak ve yıldırım olasılığı.');
      }

      // Sıcaklık
      final tMax = d.tempMax;
      if (tMax != null) {
        if (tMax >= 41) {
          add(AlertType.heat, AlertSeverity.red, 'En yüksek sıcaklık ${Fmt.tempC(tMax)}.');
        } else if (tMax >= 37) {
          add(AlertType.heat, AlertSeverity.orange, 'En yüksek sıcaklık ${Fmt.tempC(tMax)}.');
        } else if (tMax >= 33) {
          add(AlertType.heat, AlertSeverity.yellow, 'En yüksek sıcaklık ${Fmt.tempC(tMax)}.');
        }
      }
      final tMin = d.tempMin;
      if (tMin != null) {
        if (tMin <= -20) {
          add(AlertType.extremeCold, AlertSeverity.red, 'En düşük sıcaklık ${Fmt.tempC(tMin)}.');
        } else if (tMin <= -15) {
          add(AlertType.extremeCold, AlertSeverity.orange, 'En düşük sıcaklık ${Fmt.tempC(tMin)}.');
        } else if (tMin <= -10) {
          add(AlertType.extremeCold, AlertSeverity.yellow, 'En düşük sıcaklık ${Fmt.tempC(tMin)}.');
        } else if (tMin <= 0) {
          add(AlertType.frost, tMin <= -4 ? AlertSeverity.yellow : AlertSeverity.info,
              'En düşük sıcaklık ${Fmt.tempC(tMin)}; don olasılığı.');
        }
      }

      // Buzlanma
      if (codes.any(WeatherCode.isFreezing)) {
        add(AlertType.ice, AlertSeverity.orange, 'Dondurucu yağmur/çisenti bekleniyor; yollarda buzlanma olabilir.');
      } else if (tMin != null && tMin <= 0 && p >= 1) {
        add(AlertType.ice, AlertSeverity.yellow, 'Sıfırın altındaki sıcaklıkla birlikte yağış; buzlanma olasılığı.');
      }
    }

    out.sort((a, b) {
      final s = b.severity.index.compareTo(a.severity.index);
      return s != 0 ? s : a.start.compareTo(b.start);
    });
    return out;
  }
}
