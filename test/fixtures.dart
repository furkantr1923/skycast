/// Testler için küçük, elle yazılmış Open-Meteo yanıtları (gerçek şemayla aynı).
Map<String, dynamic> forecastJson({int days = 16, double rainDay0 = 0, double gust0 = 20, int code0 = 3, double tMin0 = 5}) {
  const offset = 10800; // UTC+3
  final start = DateTime.utc(2026, 11, 24).millisecondsSinceEpoch ~/ 1000 - offset;
  final hours = days * 24;
  final ht = [for (var i = 0; i < hours; i++) start + i * 3600];
  List<num?> h(num Function(int) f) => [for (var i = 0; i < hours; i++) f(i)];
  final dt = [for (var d = 0; d < days; d++) start + d * 86400];
  List<num?> d(num Function(int) f) => [for (var i = 0; i < days; i++) f(i)];
  return {
    'latitude': 41.0,
    'longitude': 29.0,
    'utc_offset_seconds': offset,
    'timezone': 'Europe/Istanbul',
    'elevation': 40.0,
    'current': {
      'time': start + 14 * 3600,
      'temperature_2m': 12.4,
      'relative_humidity_2m': 71,
      'apparent_temperature': 10.9,
      'is_day': 1,
      'precipitation': 0.0,
      'weather_code': 3,
      'cloud_cover': 90,
      'pressure_msl': 1016.2,
      'wind_speed_10m': 14.0,
      'wind_direction_10m': 45,
      'wind_gusts_10m': 30.0,
    },
    'hourly': {
      'time': ht,
      'temperature_2m': h((i) => 8 + (i % 24) / 3),
      'relative_humidity_2m': h((i) => 70),
      'dew_point_2m': h((i) => 4),
      'apparent_temperature': h((i) => 6 + (i % 24) / 3),
      'precipitation_probability': h((i) => i < 24 && rainDay0 > 0 ? 90 : 10),
      'precipitation': h((i) => i < 24 ? rainDay0 / 24 : 0),
      'snowfall': h((i) => 0),
      'weather_code': h((i) => i < 24 ? code0 : 1),
      'pressure_msl': h((i) => 1015),
      'cloud_cover': h((i) => 50),
      'visibility': h((i) => 24000),
      'wind_speed_10m': h((i) => 12),
      'wind_direction_10m': h((i) => 200),
      'wind_gusts_10m': h((i) => 25),
      'uv_index': h((i) => 2.5),
      'is_day': h((i) => (i % 24) >= 7 && (i % 24) <= 17 ? 1 : 0),
    },
    'daily': {
      'time': dt,
      'weather_code': d((i) => i == 0 ? code0 : 1),
      'temperature_2m_max': d((i) => 15),
      'temperature_2m_min': d((i) => i == 0 ? tMin0 : 6),
      'apparent_temperature_max': d((i) => 14),
      'apparent_temperature_min': d((i) => 4),
      'sunrise': d((i) => start + i * 86400 + 7 * 3600 + 20 * 60),
      'sunset': d((i) => start + i * 86400 + 16 * 3600 + 40 * 60),
      'uv_index_max': d((i) => 3),
      'precipitation_sum': d((i) => i == 0 ? rainDay0 : 0),
      'snowfall_sum': d((i) => 0),
      'precipitation_probability_max': d((i) => i == 0 && rainDay0 > 0 ? 95 : 5),
      'wind_speed_10m_max': d((i) => 20),
      'wind_gusts_10m_max': d((i) => i == 0 ? gust0 : 30),
      'wind_direction_10m_dominant': d((i) => 200),
    },
  };
}
