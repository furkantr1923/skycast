import 'dart:ui';

enum AlertType { heavyRain, heavySnow, storm, heat, extremeCold, frost, ice, flood, hail, lightning, strongWind, other }

enum AlertSeverity { info, yellow, orange, red }

/// Uyarının kaynağı. Resmî uyarılar ile uygulamanın kendi hesapladığı
/// göstergeler hiçbir zaman karıştırılmaz.
enum AlertOrigin { official, indicator }

extension AlertTypeX on AlertType {
  String get label => switch (this) {
        AlertType.heavyRain => 'Kuvvetli yağış',
        AlertType.heavySnow => 'Yoğun kar',
        AlertType.storm => 'Fırtına',
        AlertType.heat => 'Aşırı sıcak',
        AlertType.extremeCold => 'Aşırı soğuk',
        AlertType.frost => 'Don',
        AlertType.ice => 'Buzlanma',
        AlertType.flood => 'Sel / su baskını riski',
        AlertType.hail => 'Dolu',
        AlertType.lightning => 'Yıldırım',
        AlertType.strongWind => 'Kuvvetli rüzgâr',
        AlertType.other => 'Meteorolojik uyarı',
      };
}

extension AlertSeverityX on AlertSeverity {
  String get label => switch (this) {
        AlertSeverity.info => 'Bilgi',
        AlertSeverity.yellow => 'Sarı',
        AlertSeverity.orange => 'Turuncu',
        AlertSeverity.red => 'Kırmızı',
      };

  Color get color => switch (this) {
        AlertSeverity.info => const Color(0xFF60A5FA),
        AlertSeverity.yellow => const Color(0xFFFACC15),
        AlertSeverity.orange => const Color(0xFFFB923C),
        AlertSeverity.red => const Color(0xFFEF4444),
      };
}

class WeatherAlert {
  const WeatherAlert({
    required this.id,
    required this.type,
    required this.severity,
    required this.origin,
    required this.title,
    required this.description,
    required this.placeName,
    required this.start,
    this.end,
    this.source,
    this.sourceUrl,
    this.firstSeen,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final AlertOrigin origin;
  final String title;
  final String description;
  final String placeName;

  /// Konumun yerel saatiyle başlangıç/bitiş.
  final DateTime start;
  final DateTime? end;
  final String? source;
  final String? sourceUrl;

  /// Geçmiş için: ilk görüldüğü cihaz zamanı.
  final DateTime? firstSeen;

  String get originLabel =>
      origin == AlertOrigin.official ? 'Resmî uyarı · ${source ?? 'ulusal meteoroloji servisi'}' : 'Uygulama göstergesi · resmî uyarı değil';

  WeatherAlert withFirstSeen(DateTime t) => WeatherAlert(
        id: id,
        type: type,
        severity: severity,
        origin: origin,
        title: title,
        description: description,
        placeName: placeName,
        start: start,
        end: end,
        source: source,
        sourceUrl: sourceUrl,
        firstSeen: t,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'sev': severity.name,
        'origin': origin.name,
        'title': title,
        'desc': description,
        'place': placeName,
        'start': start.toIso8601String(),
        'end': end?.toIso8601String(),
        'source': source,
        'url': sourceUrl,
        'seen': firstSeen?.toIso8601String(),
      };

  factory WeatherAlert.fromJson(Map<String, dynamic> j) => WeatherAlert(
        id: j['id'] as String,
        type: AlertType.values.firstWhere((e) => e.name == j['type'], orElse: () => AlertType.other),
        severity: AlertSeverity.values.firstWhere((e) => e.name == j['sev'], orElse: () => AlertSeverity.info),
        origin: AlertOrigin.values.firstWhere((e) => e.name == j['origin'], orElse: () => AlertOrigin.indicator),
        title: j['title'] as String,
        description: j['desc'] as String,
        placeName: j['place'] as String,
        start: DateTime.parse(j['start'] as String),
        end: j['end'] == null ? null : DateTime.parse(j['end'] as String),
        source: j['source'] as String?,
        sourceUrl: j['url'] as String?,
        firstSeen: j['seen'] == null ? null : DateTime.parse(j['seen'] as String),
      );
}
