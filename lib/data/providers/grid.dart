import 'dart:math' as math;

import '../../core/failure.dart';
import '../../core/http.dart';

enum GridVariable { precipitation, cloud, temperature, wind, pressure }

extension GridVariableX on GridVariable {
  String get label => switch (this) {
        GridVariable.precipitation => 'Yağış',
        GridVariable.cloud => 'Bulut',
        GridVariable.temperature => 'Sıcaklık',
        GridVariable.wind => 'Rüzgâr',
        GridVariable.pressure => 'Basınç',
      };

  String get unit => switch (this) {
        GridVariable.precipitation => 'mm/sa',
        GridVariable.cloud => '%',
        GridVariable.temperature => '°C',
        GridVariable.wind => 'km/sa',
        GridVariable.pressure => 'hPa',
      };
}

/// Harita için düzenli ızgara üzerinde gerçek model değerleri.
class GridField {
  GridField({
    required this.south,
    required this.north,
    required this.west,
    required this.east,
    required this.rows,
    required this.cols,
    required this.time,
    required this.values,
    required this.windDirection,
  });

  final double south, north, west, east;
  final int rows, cols;

  /// Model zamanı (UTC).
  final DateTime time;

  /// [değişken][satır * cols + sütun]; satır 0 = güney.
  final Map<GridVariable, List<double?>> values;
  final List<double?> windDirection;

  double latAt(int r) => south + (north - south) * r / (rows - 1);
  double lonAt(int c) => west + (east - west) * c / (cols - 1);

  /// İki doğrusal enterpolasyon; eksik değer varsa null.
  double? sample(GridVariable v, double lat, double lon) {
    final list = values[v]!;
    final fr = ((lat - south) / (north - south) * (rows - 1)).clamp(0.0, rows - 1.0);
    final fc = ((lon - west) / (east - west) * (cols - 1)).clamp(0.0, cols - 1.0);
    final r0 = fr.floor(), c0 = fc.floor();
    final r1 = math.min(r0 + 1, rows - 1), c1 = math.min(c0 + 1, cols - 1);
    final a = list[r0 * cols + c0], b = list[r0 * cols + c1], c = list[r1 * cols + c0], d = list[r1 * cols + c1];
    if (a == null || b == null || c == null || d == null) return a ?? b ?? c ?? d;
    final tr = fr - r0, tc = fc - c0;
    return (a * (1 - tc) + b * tc) * (1 - tr) + (c * (1 - tc) + d * tc) * tr;
  }
}

/// Open-Meteo çoklu konum isteğiyle görünen harita alanı için ızgara verisi
/// alır. Kaynak ücretsiz katmanda her nokta bir istek sayıldığından ızgara
/// küçük tutulur ve sonuçlar önbelleğe alınır.
class GridProvider {
  const GridProvider();

  static const source = 'Open-Meteo';

  Future<GridField> fetch({
    required double south,
    required double north,
    required double west,
    required double east,
    int rows = 7,
    int cols = 9,
  }) async {
    final lats = <String>[], lons = <String>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        lats.add((south + (north - south) * r / (rows - 1)).toStringAsFixed(3));
        lons.add((west + (east - west) * c / (cols - 1)).toStringAsFixed(3));
      }
    }
    final res = await Http.getJson('https://api.open-meteo.com/v1/forecast', source: source, query: {
      'latitude': lats.join(','),
      'longitude': lons.join(','),
      'current': 'temperature_2m,precipitation,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m',
      'timeformat': 'unixtime',
      'wind_speed_unit': 'kmh',
    });
    final list = res is List ? res : [res];
    if (list.length != rows * cols) {
      throw AppFailure(FailureKind.invalidResponse, source: source, detail: 'nokta sayısı ${list.length}');
    }
    double? v(Map m, String k) => m[k] is num ? (m[k] as num).toDouble() : null;
    final values = {for (final g in GridVariable.values) g: <double?>[]};
    final dirs = <double?>[];
    DateTime? time;
    for (final item in list.whereType<Map>()) {
      final c = item['current'] as Map? ?? const {};
      if (time == null && c['time'] is num) {
        time = DateTime.fromMillisecondsSinceEpoch((c['time'] as num).toInt() * 1000, isUtc: true);
      }
      values[GridVariable.temperature]!.add(v(c, 'temperature_2m'));
      values[GridVariable.precipitation]!.add(v(c, 'precipitation'));
      values[GridVariable.cloud]!.add(v(c, 'cloud_cover'));
      values[GridVariable.pressure]!.add(v(c, 'pressure_msl'));
      values[GridVariable.wind]!.add(v(c, 'wind_speed_10m'));
      dirs.add(v(c, 'wind_direction_10m'));
    }
    return GridField(
      south: south,
      north: north,
      west: west,
      east: east,
      rows: rows,
      cols: cols,
      time: time ?? DateTime.now().toUtc(),
      values: values,
      windDirection: dirs,
    );
  }
}
