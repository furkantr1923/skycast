import '../../core/failure.dart';
import '../../core/http.dart';
import '../../domain/weather.dart';

/// Open-Meteo Forecast API (https://open-meteo.com) — anahtarsız, ücretsiz
/// (ticari olmayan kullanım), CC BY 4.0 lisanslı veri. En fazla 16 gün tahmin.
class OpenMeteoForecastProvider {
  const OpenMeteoForecastProvider({this.endpoint = defaultEndpoint});

  final String endpoint;

  static const source = 'Open-Meteo';
  static const defaultEndpoint = 'https://api.open-meteo.com/v1/forecast';
  static const forecastDays = 16;

  static const _current = [
    'temperature_2m', 'relative_humidity_2m', 'apparent_temperature', 'is_day', 'precipitation', //
    'weather_code', 'cloud_cover', 'pressure_msl', 'wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m',
  ];
  static const _hourly = [
    'temperature_2m', 'relative_humidity_2m', 'dew_point_2m', 'apparent_temperature', //
    'precipitation_probability', 'precipitation', 'snowfall', 'weather_code', 'pressure_msl', 'cloud_cover',
    'visibility', 'wind_speed_10m', 'wind_direction_10m', 'wind_gusts_10m', 'uv_index', 'is_day',
  ];
  static const _daily = [
    'weather_code', 'temperature_2m_max', 'temperature_2m_min', 'apparent_temperature_max', //
    'apparent_temperature_min', 'sunrise', 'sunset', 'uv_index_max', 'precipitation_sum', 'snowfall_sum',
    'precipitation_probability_max', 'wind_speed_10m_max', 'wind_gusts_10m_max', 'wind_direction_10m_dominant',
  ];

  Future<Forecast> fetch(double lat, double lon) async {
    final json = await Http.getJson(endpoint, source: source, query: {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': _current.join(','),
      'hourly': _hourly.join(','),
      'daily': _daily.join(','),
      'timezone': 'auto',
      'timeformat': 'unixtime',
      'forecast_days': '$forecastDays',
      'wind_speed_unit': 'kmh',
      'temperature_unit': 'celsius',
      'precipitation_unit': 'mm',
    });
    return parse(json as Map<String, dynamic>);
  }

  /// Ham yanıtı alan modeline çevirir. Test edilebilir olsun diye ayrıdır.
  static Forecast parse(Map<String, dynamic> j, {DateTime? fetchedAt}) {
    try {
      final clock = LocalClock((j['utc_offset_seconds'] as num? ?? 0).toInt(), j['timezone'] as String? ?? 'GMT');
      final c = j['current'] as Map<String, dynamic>?;
      final h = j['hourly'] as Map<String, dynamic>?;
      final d = j['daily'] as Map<String, dynamic>?;
      if (c == null || h == null || d == null) {
        throw const AppFailure(FailureKind.invalidResponse, source: source, detail: 'eksik bölüm');
      }

      double? numAt(Map<String, dynamic> m, String k, int i) {
        final list = m[k];
        if (list is! List || i >= list.length) return null;
        final v = list[i];
        return v is num ? v.toDouble() : null;
      }

      double? cur(String k) => c[k] is num ? (c[k] as num).toDouble() : null;

      final hTimes = (h['time'] as List).cast<num>();
      final hourly = <HourlyPoint>[
        for (var i = 0; i < hTimes.length; i++)
          HourlyPoint(
            time: clock.wall(hTimes[i].toInt()),
            temperature: numAt(h, 'temperature_2m', i),
            apparentTemperature: numAt(h, 'apparent_temperature', i),
            humidity: numAt(h, 'relative_humidity_2m', i),
            dewPoint: numAt(h, 'dew_point_2m', i),
            precipitationProbability: numAt(h, 'precipitation_probability', i),
            precipitation: numAt(h, 'precipitation', i),
            snowfall: numAt(h, 'snowfall', i),
            weatherCode: numAt(h, 'weather_code', i)?.toInt(),
            pressure: numAt(h, 'pressure_msl', i),
            cloudCover: numAt(h, 'cloud_cover', i),
            visibility: numAt(h, 'visibility', i),
            windSpeed: numAt(h, 'wind_speed_10m', i),
            windDirection: numAt(h, 'wind_direction_10m', i),
            windGusts: numAt(h, 'wind_gusts_10m', i),
            uvIndex: numAt(h, 'uv_index', i),
            isDay: (numAt(h, 'is_day', i) ?? 1) >= 1,
          ),
      ];

      final dTimes = (d['time'] as List).cast<num>();
      final daily = <DailyPoint>[];
      for (var i = 0; i < dTimes.length; i++) {
        final date = clock.wall(dTimes[i].toInt());
        final dayHours = hourly.where((p) => p.time.year == date.year && p.time.month == date.month && p.time.day == date.day);
        double? mean(double? Function(HourlyPoint) f) {
          final vals = dayHours.map(f).whereType<double>().toList();
          if (vals.isEmpty) return null;
          return vals.reduce((a, b) => a + b) / vals.length;
        }

        DateTime? t(String k) {
          final v = numAt(d, k, i);
          return v == null ? null : clock.wall(v.toInt());
        }

        daily.add(DailyPoint(
          date: DateTime.utc(date.year, date.month, date.day),
          weatherCode: numAt(d, 'weather_code', i)?.toInt(),
          tempMax: numAt(d, 'temperature_2m_max', i),
          tempMin: numAt(d, 'temperature_2m_min', i),
          apparentMax: numAt(d, 'apparent_temperature_max', i),
          apparentMin: numAt(d, 'apparent_temperature_min', i),
          sunrise: t('sunrise'),
          sunset: t('sunset'),
          uvIndexMax: numAt(d, 'uv_index_max', i),
          precipitationSum: numAt(d, 'precipitation_sum', i),
          snowfallSum: numAt(d, 'snowfall_sum', i),
          precipitationProbabilityMax: numAt(d, 'precipitation_probability_max', i),
          windSpeedMax: numAt(d, 'wind_speed_10m_max', i),
          windGustsMax: numAt(d, 'wind_gusts_10m_max', i),
          windDirectionDominant: numAt(d, 'wind_direction_10m_dominant', i),
          humidityMean: mean((p) => p.humidity),
          pressureMean: mean((p) => p.pressure),
        ));
      }
      // Tahmin verisi olmayan (tamamen boş) günleri gösterme; asla uydurma değer koyma.
      daily.removeWhere((x) => x.tempMax == null && x.tempMin == null && x.weatherCode == null);

      final curTime = clock.wall((c['time'] as num).toInt());
      // Anlık yanıtta olmayan UV, görüş, çiy noktası ve yağış olasılığı içinde
      // bulunulan saatin değerinden alınır.
      final hourIdx = hourly.lastIndexWhere((p) => !p.time.isAfter(curTime));
      final nowHour = hourIdx >= 0 ? hourly[hourIdx] : null;

      final current = CurrentConditions(
        time: curTime,
        temperature: cur('temperature_2m'),
        apparentTemperature: cur('apparent_temperature'),
        humidity: cur('relative_humidity_2m'),
        pressure: cur('pressure_msl'),
        windSpeed: cur('wind_speed_10m'),
        windDirection: cur('wind_direction_10m'),
        windGusts: cur('wind_gusts_10m'),
        cloudCover: cur('cloud_cover'),
        precipitation: cur('precipitation'),
        weatherCode: cur('weather_code')?.toInt(),
        isDay: (cur('is_day') ?? 1) >= 1,
        uvIndex: nowHour?.uvIndex,
        visibility: nowHour?.visibility,
        dewPoint: nowHour?.dewPoint,
        precipitationProbability: nowHour?.precipitationProbability,
      );

      return Forecast(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        elevation: (j['elevation'] as num?)?.toDouble(),
        clock: clock,
        current: current,
        hourly: hourly,
        daily: daily,
        fetchedAt: fetchedAt ?? DateTime.now(),
      );
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw AppFailure(FailureKind.invalidResponse, source: source, detail: '$e');
    }
  }
}
