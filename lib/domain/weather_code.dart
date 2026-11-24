/// WMO hava durumu kodlarının Türkçe karşılıkları ve görsel sınıfları.
enum SkyKind { clear, partly, cloudy, fog, drizzle, rain, freezingRain, snow, thunder, hail }

class WeatherCode {
  WeatherCode._();

  static String describe(int? code) => switch (code) {
        0 => 'Açık',
        1 => 'Çoğunlukla açık',
        2 => 'Parçalı bulutlu',
        3 => 'Kapalı',
        45 => 'Sisli',
        48 => 'Kırağılı sis',
        51 => 'Hafif çisenti',
        53 => 'Çisenti',
        55 => 'Yoğun çisenti',
        56 => 'Hafif dondurucu çisenti',
        57 => 'Dondurucu çisenti',
        61 => 'Hafif yağmur',
        63 => 'Yağmur',
        65 => 'Kuvvetli yağmur',
        66 => 'Hafif dondurucu yağmur',
        67 => 'Dondurucu yağmur',
        71 => 'Hafif kar',
        73 => 'Kar',
        75 => 'Yoğun kar',
        77 => 'Kar taneleri',
        80 => 'Hafif sağanak',
        81 => 'Sağanak yağış',
        82 => 'Şiddetli sağanak',
        85 => 'Hafif kar sağanağı',
        86 => 'Kuvvetli kar sağanağı',
        95 => 'Gök gürültülü sağanak',
        96 => 'Dolu ile gök gürültülü fırtına',
        99 => 'Kuvvetli dolu ile fırtına',
        null => 'Bilinmiyor',
        _ => 'Bilinmeyen durum ($code)',
      };

  static SkyKind kind(int? code) => switch (code) {
        0 || 1 => SkyKind.clear,
        2 => SkyKind.partly,
        3 => SkyKind.cloudy,
        45 || 48 => SkyKind.fog,
        51 || 53 || 55 => SkyKind.drizzle,
        56 || 57 || 66 || 67 => SkyKind.freezingRain,
        61 || 63 || 65 || 80 || 81 || 82 => SkyKind.rain,
        71 || 73 || 75 || 77 || 85 || 86 => SkyKind.snow,
        95 => SkyKind.thunder,
        96 || 99 => SkyKind.hail,
        _ => SkyKind.cloudy,
      };

  static bool isThunder(int? c) => c == 95 || c == 96 || c == 99;
  static bool isHail(int? c) => c == 96 || c == 99;
  static bool isFreezing(int? c) => c == 56 || c == 57 || c == 66 || c == 67;
}
