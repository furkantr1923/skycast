/// Konumun yerel saatini temsil eder.
///
/// Open-Meteo zamanları Unix saniyesi + konumun UTC farkı olarak gelir. Tüm
/// zamanlar "konumun duvar saati" olarak tutulur (UTC alanlarında saklanır),
/// böylece cihazın saat diliminden bağımsız olarak doğru gösterilir.
class LocalClock {
  const LocalClock(this.utcOffsetSeconds, this.timezone);

  final int utcOffsetSeconds;
  final String timezone;

  DateTime wall(int unixSeconds) =>
      DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true).add(Duration(seconds: utcOffsetSeconds));

  DateTime now([DateTime? reference]) =>
      (reference ?? DateTime.now()).toUtc().add(Duration(seconds: utcOffsetSeconds));

  String get offsetLabel {
    final h = utcOffsetSeconds ~/ 3600;
    final m = (utcOffsetSeconds.abs() % 3600) ~/ 60;
    final sign = utcOffsetSeconds >= 0 ? '+' : '-';
    return 'UTC$sign${h.abs()}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}';
  }
}

class CurrentConditions {
  const CurrentConditions({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDirection,
    required this.windGusts,
    required this.cloudCover,
    required this.precipitation,
    required this.weatherCode,
    required this.isDay,
    this.uvIndex,
    this.visibility,
    this.dewPoint,
    this.precipitationProbability,
  });

  final DateTime time;
  final double? temperature;
  final double? apparentTemperature;
  final double? humidity;
  final double? pressure;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;
  final double? cloudCover;
  final double? precipitation;
  final int? weatherCode;
  final bool isDay;
  final double? uvIndex;
  final double? visibility;
  final double? dewPoint;
  final double? precipitationProbability;
}

class HourlyPoint {
  const HourlyPoint({
    required this.time,
    this.temperature,
    this.apparentTemperature,
    this.humidity,
    this.dewPoint,
    this.precipitationProbability,
    this.precipitation,
    this.snowfall,
    this.weatherCode,
    this.pressure,
    this.cloudCover,
    this.visibility,
    this.windSpeed,
    this.windDirection,
    this.windGusts,
    this.uvIndex,
    this.isDay = true,
  });

  final DateTime time;
  final double? temperature;
  final double? apparentTemperature;
  final double? humidity;
  final double? dewPoint;
  final double? precipitationProbability;
  final double? precipitation;
  final double? snowfall;
  final int? weatherCode;
  final double? pressure;
  final double? cloudCover;
  final double? visibility;
  final double? windSpeed;
  final double? windDirection;
  final double? windGusts;
  final double? uvIndex;
  final bool isDay;
}

class DailyPoint {
  const DailyPoint({
    required this.date,
    this.weatherCode,
    this.tempMax,
    this.tempMin,
    this.apparentMax,
    this.apparentMin,
    this.sunrise,
    this.sunset,
    this.uvIndexMax,
    this.precipitationSum,
    this.snowfallSum,
    this.precipitationProbabilityMax,
    this.windSpeedMax,
    this.windGustsMax,
    this.windDirectionDominant,
    this.humidityMean,
    this.pressureMean,
  });

  final DateTime date;
  final int? weatherCode;
  final double? tempMax;
  final double? tempMin;
  final double? apparentMax;
  final double? apparentMin;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? uvIndexMax;
  final double? precipitationSum;
  final double? snowfallSum;
  final double? precipitationProbabilityMax;
  final double? windSpeedMax;
  final double? windGustsMax;
  final double? windDirectionDominant;

  /// Saatlik veriden hesaplanan günlük ortalamalar (grafikler için).
  final double? humidityMean;
  final double? pressureMean;
}

/// Bir konumun tahmin paketi. [fetchedAt] cihaz saatidir, diğer zamanlar konum saatidir.
class Forecast {
  const Forecast({
    required this.latitude,
    required this.longitude,
    required this.clock,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.fetchedAt,
    required this.elevation,
  });

  final double latitude;
  final double longitude;
  final double? elevation;
  final LocalClock clock;
  final CurrentConditions current;

  /// Tüm saatlik seri (16 güne kadar).
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;
  final DateTime fetchedAt;

  /// Şu andan itibaren saatlik noktalar.
  List<HourlyPoint> upcomingHours([int count = 48]) {
    final now = clock.now();
    final start = hourly.indexWhere((h) => !h.time.isBefore(DateTime.utc(now.year, now.month, now.day, now.hour)));
    if (start < 0) return const [];
    return hourly.sublist(start, (start + count).clamp(start, hourly.length));
  }

  DailyPoint? get today => daily.isEmpty ? null : daily.first;

  /// Gündüz mü? (anlık veride is_day yoksa gün doğumu/batımı kullanılır)
  bool get isDay => current.isDay;

  /// Verinin yaşı: önbellekten geliyorsa kullanıcıya gösterilir.
  Duration get age => DateTime.now().difference(fetchedAt);
}

class AirQuality {
  const AirQuality({
    required this.time,
    required this.fetchedAt,
    this.europeanAqi,
    this.usAqi,
  });

  final DateTime time;
  final DateTime fetchedAt;
  final double? europeanAqi;
  final double? usAqi;
}
