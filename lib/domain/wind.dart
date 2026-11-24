/// Rüzgâr yardımcıları: Beaufort ölçeği ve Türkçe yön adları.
class Wind {
  Wind._();

  /// km/sa → Beaufort (0–12). WMO eşikleri kullanılır.
  static int beaufort(double? kmh) {
    if (kmh == null) return 0;
    const limits = [1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];
    for (var i = 0; i < limits.length; i++) {
      if (kmh < limits[i]) return i;
    }
    return 12;
  }

  static const _bftNames = [
    'Sakin',
    'Esinti',
    'Hafif rüzgâr',
    'Tatlı rüzgâr',
    'Mutedil rüzgâr',
    'Sert rüzgâr',
    'Kuvvetli rüzgâr',
    'Fırtınamsı rüzgâr',
    'Fırtına',
    'Kuvvetli fırtına',
    'Tam fırtına',
    'Çok şiddetli fırtına',
    'Kasırga',
  ];

  static String beaufortName(int b) => _bftNames[b.clamp(0, 12)];

  static const _dirs = [
    'K', 'KKD', 'KD', 'DKD', 'D', 'DGD', 'GD', 'GGD', //
    'G', 'GGB', 'GB', 'BGB', 'B', 'BKB', 'KB', 'KKB',
  ];

  static const _dirNames = {
    'K': 'Kuzey', 'KD': 'Kuzeydoğu', 'D': 'Doğu', 'GD': 'Güneydoğu', //
    'G': 'Güney', 'GB': 'Güneybatı', 'B': 'Batı', 'KB': 'Kuzeybatı',
  };

  /// Rüzgârın estiği yön (meteorolojik: "nereden"), 16 yönlü kısaltma.
  static String direction(double? deg) {
    if (deg == null) return '—';
    final i = (((deg % 360) / 22.5) + 0.5).floor() % 16;
    return _dirs[i];
  }

  /// 8 yönlü tam ad: "Kuzeydoğu".
  static String directionName(double? deg) {
    if (deg == null) return 'Bilinmiyor';
    final i = (((deg % 360) / 45) + 0.5).floor() % 8;
    return _dirNames[['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'][i]]!;
  }
}
