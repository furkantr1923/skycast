import '../../core/failure.dart';
import '../../core/http.dart';
import '../../domain/place.dart';

/// Şehir arama: Open-Meteo Geocoding (GeoNames verisi, anahtarsız).
class GeocodingProvider {
  const GeocodingProvider();

  static const source = 'Open-Meteo Geocoding';

  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final j = await Http.getJson('https://geocoding-api.open-meteo.com/v1/search', source: source, query: {
      'name': q,
      'count': '15',
      'language': 'tr',
      'format': 'json',
    }) as Map<String, dynamic>;
    return parse(j);
  }

  static List<Place> parse(Map<String, dynamic> j) {
    final results = j['results'];
    if (results is! List) return const [];
    return [
      for (final r in results.whereType<Map>())
        if (r['latitude'] is num && r['longitude'] is num)
          Place(
            name: '${r['name']}',
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
            region: r['admin1'] as String?,
            country: r['country'] as String?,
            countryCode: (r['country_code'] as String?)?.toUpperCase(),
          ),
    ];
  }
}

/// Koordinattan yer adı: OpenStreetMap Nominatim (ODbL). Kullanım politikası
/// gereği tanımlayıcı User-Agent gönderilir ve istekler seyrek tutulur
/// (yalnızca GPS ve harita dokunuşunda, saniyede en fazla bir istek).
class ReverseGeocoder {
  ReverseGeocoder();

  static const source = 'OpenStreetMap Nominatim';
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Place> reverse(double lat, double lon, {bool isGps = false}) async {
    final fallback = Place(name: _coordName(lat, lon), latitude: lat, longitude: lon, isGps: isGps);
    final wait = const Duration(milliseconds: 1100) - DateTime.now().difference(_last);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    _last = DateTime.now();
    try {
      final j = await Http.getJson('https://nominatim.openstreetmap.org/reverse', source: source, query: {
        'lat': lat.toStringAsFixed(5),
        'lon': lon.toStringAsFixed(5),
        'format': 'jsonv2',
        'accept-language': 'tr',
        'zoom': '10',
      }) as Map<String, dynamic>;
      final p = parse(j, lat, lon, isGps: isGps);
      return p ?? fallback;
    } on AppFailure catch (f) {
      // Yer adı bulunamazsa koordinatla devam edilir; hava durumu yine gerçek veridir.
      if (f.kind == FailureKind.offline) rethrow;
      return fallback;
    }
  }

  static Place? parse(Map<String, dynamic> j, double lat, double lon, {bool isGps = false}) {
    final a = j['address'];
    if (a is! Map) return null;
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = a[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final name = pick(['town', 'city', 'village', 'municipality', 'county', 'province', 'state', 'region']) ??
        (j['name'] is String && (j['name'] as String).isNotEmpty ? j['name'] as String : null);
    if (name == null) return null;
    final region = pick(['province', 'state', 'region']);
    return Place(
      name: name,
      latitude: lat,
      longitude: lon,
      region: region == name ? pick(['region']) : region,
      country: pick(['country']),
      countryCode: (a['country_code'] as String?)?.toUpperCase(),
      isGps: isGps,
    );
  }

  static String _coordName(double lat, double lon) =>
      '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
}
