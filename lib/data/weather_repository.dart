import '../core/ttl_cache.dart';
import '../domain/alert.dart';
import '../domain/place.dart';
import '../domain/weather.dart';
import 'providers/geocoding.dart';
import 'providers/grid.dart';
import 'providers/meteoalarm.dart';
import 'providers/open_meteo_air.dart';
import 'providers/open_meteo_forecast.dart';
import 'providers/radar.dart';
import 'providers/satellite.dart';

/// Veri kaynakları ile uygulama arasındaki tek giriş noktası.
///
/// Sağlayıcılar birbirinden bağımsızdır: biri çökerse yalnızca o özellik
/// "kullanılamıyor" durumuna geçer. Bellek önbelleği gereksiz istekleri
/// önler; "Yenile" her zaman önbelleği atlar.
class WeatherRepository {
  WeatherRepository({
    this.forecastProvider = const OpenMeteoForecastProvider(),
    this.airProvider = const OpenMeteoAirProvider(),
    this.geocoding = const GeocodingProvider(),
    ReverseGeocoder? reverse,
    this.radarProvider = const RainViewerProvider(),
    this.satelliteProvider = const SatelliteProvider(),
    this.alarmProvider = const MeteoAlarmProvider(),
    this.gridProvider = const GridProvider(),
  }) : reverse = reverse ?? ReverseGeocoder();

  /// Değiştirilebilir: öz-sınamada gerçek bir bağlantı hatası üretmek için.
  OpenMeteoForecastProvider forecastProvider;
  final OpenMeteoAirProvider airProvider;
  final GeocodingProvider geocoding;
  final ReverseGeocoder reverse;
  final RainViewerProvider radarProvider;
  final SatelliteProvider satelliteProvider;
  final MeteoAlarmProvider alarmProvider;
  final GridProvider gridProvider;

  final _forecast = TtlCache<Forecast>(const Duration(minutes: 10));
  final _air = TtlCache<AirQuality>(const Duration(minutes: 30));
  final _radar = TtlCache<RadarSet>(const Duration(minutes: 5), maxEntries: 1);
  final _alarm = TtlCache<List<WeatherAlert>>(const Duration(minutes: 15));
  final _grid = TtlCache<GridField>(const Duration(minutes: 15), maxEntries: 24);
  final _sat = TtlCache<List<SatelliteFrame>>(const Duration(minutes: 5), maxEntries: 12);

  Future<Forecast> forecast(Place p, {bool force = false}) async {
    if (!force) {
      final c = _forecast.get(p.key);
      if (c != null) return c;
    }
    final f = await forecastProvider.fetch(p.latitude, p.longitude);
    _forecast.put(p.key, f);
    return f;
  }

  Future<AirQuality> air(Place p, {bool force = false}) async {
    if (!force) {
      final c = _air.get(p.key);
      if (c != null) return c;
    }
    final a = await airProvider.fetch(p.latitude, p.longitude);
    _air.put(p.key, a);
    return a;
  }

  Future<List<WeatherAlert>> officialAlerts(Place p, {bool force = false}) async {
    if (!force) {
      final c = _alarm.get(p.key);
      if (c != null) return c;
    }
    final a = await alarmProvider.fetch(p);
    _alarm.put(p.key, a);
    return a;
  }

  Future<RadarSet> radar({bool force = false}) async {
    if (!force) {
      final c = _radar.get('r');
      if (c != null) return c;
    }
    final r = await radarProvider.fetch();
    _radar.put('r', r);
    return r;
  }

  Future<List<SatelliteFrame>> satelliteFrames(SatelliteLayer layer, Duration span, {bool force = false}) async {
    final key = '${layer.id}:${span.inMinutes}';
    if (!force) {
      final c = _sat.get(key);
      if (c != null) return c;
    }
    final f = await satelliteProvider.frames(layer, span: span, count: layer.isDaily ? 10 : 13);
    _sat.put(key, f);
    return f;
  }

  Future<GridField> grid({required double south, required double north, required double west, required double east}) async {
    // Önbellek anahtarı: alanı 0,5° adımlara yuvarla ki küçük kaydırmalar yeni istek yapmasın.
    double r(double v) => (v * 2).roundToDouble() / 2;
    final s = r(south), n = r(north), w = r(west), e = r(east);
    final key = '$s,$n,$w,$e';
    final c = _grid.get(key);
    if (c != null) return c;
    final g = await gridProvider.fetch(south: s, north: n == s ? s + 0.5 : n, west: w, east: e == w ? w + 0.5 : e);
    _grid.put(key, g);
    return g;
  }

  Future<List<Place>> search(String q) => geocoding.search(q);

  Future<Place> placeAt(double lat, double lon, {bool isGps = false}) => reverse.reverse(lat, lon, isGps: isGps);

  void clearCache() {
    _forecast.clear();
    _air.clear();
    _radar.clear();
    _alarm.clear();
    _grid.clear();
    _sat.clear();
  }
}
