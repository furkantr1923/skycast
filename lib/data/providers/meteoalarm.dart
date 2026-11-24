import '../../core/failure.dart';
import '../../core/http.dart';
import '../../domain/alert.dart';
import '../../domain/place.dart';

/// MeteoAlarm (EUMETNET) — Avrupa ulusal meteoroloji servislerinin RESMÎ
/// uyarıları. Türkiye MeteoAlarm akışında yer almıyor (kaynak 404 döndürür);
/// bu durumda uygulama bunu açıkça belirtir ve resmî uyarı uydurmaz.
class MeteoAlarmProvider {
  const MeteoAlarmProvider();

  static const source = 'MeteoAlarm';

  static const feeds = {
    'AT': 'austria', 'BE': 'belgium', 'BA': 'bosnia-herzegovina', 'BG': 'bulgaria', 'HR': 'croatia', //
    'CY': 'cyprus', 'CZ': 'czechia', 'DK': 'denmark', 'EE': 'estonia', 'FI': 'finland', 'FR': 'france',
    'DE': 'germany', 'GR': 'greece', 'HU': 'hungary', 'IS': 'iceland', 'IE': 'ireland', 'IL': 'israel',
    'IT': 'italy', 'LV': 'latvia', 'LT': 'lithuania', 'LU': 'luxembourg', 'MT': 'malta', 'MD': 'moldova',
    'ME': 'montenegro', 'NL': 'netherlands', 'MK': 'republic-of-north-macedonia', 'NO': 'norway',
    'PL': 'poland', 'PT': 'portugal', 'RO': 'romania', 'RS': 'serbia', 'SK': 'slovakia', 'SI': 'slovenia',
    'ES': 'spain', 'SE': 'sweden', 'CH': 'switzerland', 'UA': 'ukraine', 'GB': 'united-kingdom',
  };

  static bool covers(String? countryCode) => countryCode != null && feeds.containsKey(countryCode.toUpperCase());

  Future<List<WeatherAlert>> fetch(Place place) async {
    final slug = feeds[place.countryCode?.toUpperCase()];
    if (slug == null) throw const AppFailure(FailureKind.notSupported, source: source);
    final j = await Http.getJson('https://feeds.meteoalarm.org/api/v1/warnings/feeds-$slug', source: source)
        as Map<String, dynamic>;
    return parse(j, place, now: DateTime.now().toUtc());
  }

  static String _norm(String s) {
    const map = {'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u', 'ä': 'a', 'é': 'e', 'è': 'e', 'á': 'a', 'ó': 'o', 'í': 'i', 'ß': 'ss'};
    final lower = s.toLowerCase();
    return lower.split('').map((c) => map[c] ?? c).join();
  }

  static AlertType _type(int? awarenessType) => switch (awarenessType) {
        1 => AlertType.strongWind,
        2 => AlertType.ice,
        3 => AlertType.lightning,
        5 => AlertType.heat,
        6 => AlertType.extremeCold,
        10 => AlertType.heavyRain,
        12 || 13 => AlertType.flood,
        _ => AlertType.other,
      };

  static AlertSeverity _severity(String? level) {
    final l = (level ?? '').toLowerCase();
    if (l.contains('red')) return AlertSeverity.red;
    if (l.contains('orange')) return AlertSeverity.orange;
    if (l.contains('yellow')) return AlertSeverity.yellow;
    return AlertSeverity.info;
  }

  /// Uyarılar alan adına göre eşleştirilir (akışta geometri yok): konum adı ya
  /// da bölge adı uyarı alanının adında geçiyorsa gösterilir.
  static List<WeatherAlert> parse(Map<String, dynamic> j, Place place, {required DateTime now}) {
    final list = j['warnings'];
    if (list is! List) return const [];
    final keys = {_norm(place.name), if (place.region != null) _norm(place.region!)}..removeWhere((k) => k.length < 3);
    final out = <String, WeatherAlert>{};
    for (final w in list.whereType<Map>()) {
      final alert = w['alert'];
      if (alert is! Map) continue;
      final infos = (alert['info'] as List?)?.whereType<Map>().toList() ?? const [];
      if (infos.isEmpty) continue;
      final info = infos.firstWhere((i) => '${i['language']}'.toLowerCase().startsWith('en'), orElse: () => infos.first);
      final areas = (info['area'] as List?)?.whereType<Map>().map((a) => '${a['areaDesc']}').toList() ?? const [];
      final matched = areas.where((a) => keys.any((k) => _norm(a).contains(k))).toList();
      if (matched.isEmpty) continue;
      final expires = DateTime.tryParse('${info['expires']}')?.toUtc();
      if (expires != null && expires.isBefore(now)) continue;
      final params = (info['parameter'] as List?)?.whereType<Map>() ?? const [];
      String? param(String name) => params.where((p) => p['valueName'] == name).map((p) => '${p['value']}').firstOrNull;
      final typeNum = int.tryParse((param('awareness_type') ?? '').split(';').first.trim());
      final sev = _severity(param('awareness_level'));
      final id = 'off:${alert['identifier']}';
      out[id] = WeatherAlert(
        id: id,
        type: _type(typeNum),
        severity: sev,
        origin: AlertOrigin.official,
        title: '${info['event'] ?? info['headline'] ?? 'Resmî uyarı'}',
        description: [info['headline'], info['description']].whereType<String>().where((s) => s.isNotEmpty).join('\n'),
        placeName: matched.first,
        start: DateTime.tryParse('${info['onset'] ?? info['effective']}')?.toUtc() ?? now,
        end: expires,
        source: '${info['senderName'] ?? 'MeteoAlarm'}',
        sourceUrl: 'https://meteoalarm.org',
      );
    }
    return out.values.toList()..sort((a, b) => b.severity.index.compareTo(a.severity.index));
  }
}
