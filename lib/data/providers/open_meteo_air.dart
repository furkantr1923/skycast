import '../../core/failure.dart';
import '../../core/http.dart';
import '../../domain/weather.dart';

/// Open-Meteo Air Quality API (CAMS tabanlı). Yalnızca AQI değerleri istenir.
class OpenMeteoAirProvider {
  const OpenMeteoAirProvider();

  static const source = 'Open-Meteo Air Quality (CAMS)';
  static const endpoint = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  Future<AirQuality> fetch(double lat, double lon) async {
    final j = await Http.getJson(endpoint, source: source, query: {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'european_aqi,us_aqi',
      'timezone': 'auto',
      'timeformat': 'unixtime',
    }) as Map<String, dynamic>;
    return parse(j);
  }

  static AirQuality parse(Map<String, dynamic> j, {DateTime? fetchedAt}) {
    final c = j['current'];
    if (c is! Map) throw const AppFailure(FailureKind.invalidResponse, source: source);
    final clock = LocalClock((j['utc_offset_seconds'] as num? ?? 0).toInt(), j['timezone'] as String? ?? 'GMT');
    double? v(String k) => c[k] is num ? (c[k] as num).toDouble() : null;
    final eu = v('european_aqi');
    final us = v('us_aqi');
    if (eu == null && us == null) throw const AppFailure(FailureKind.notSupported, source: source);
    return AirQuality(
      time: clock.wall((c['time'] as num).toInt()),
      fetchedAt: fetchedAt ?? DateTime.now(),
      europeanAqi: eu,
      usAqi: us,
    );
  }
}
