import 'dart:ui';

enum AqiScale { european, us }

class AqiLevel {
  const AqiLevel(this.label, this.advice, this.color);
  final String label;
  final String advice;
  final Color color;
}

/// Hava kalitesi indeksi (yalnızca AQI) sınıflandırması.
class Aqi {
  Aqi._();

  static String scaleName(AqiScale s) => s == AqiScale.european ? 'Avrupa AQI (EAQI)' : 'ABD AQI';

  static AqiLevel level(double value, AqiScale scale) {
    if (scale == AqiScale.european) {
      if (value <= 20) return const AqiLevel('İyi', 'Hava kalitesi iyi.', Color(0xFF4ADE80));
      if (value <= 40) return const AqiLevel('Makul', 'Hava kalitesi kabul edilebilir.', Color(0xFFA3E635));
      if (value <= 60) return const AqiLevel('Orta', 'Hassas kişiler uzun süreli efordan kaçınmalı.', Color(0xFFFACC15));
      if (value <= 80) return const AqiLevel('Kötü', 'Dış mekân etkinliklerini azaltın.', Color(0xFFFB923C));
      if (value <= 100) return const AqiLevel('Çok kötü', 'Dış mekânda uzun süre kalmayın.', Color(0xFFF87171));
      return const AqiLevel('Son derece kötü', 'Dış mekân etkinliklerinden kaçının.', Color(0xFFC084FC));
    }
    if (value <= 50) return const AqiLevel('İyi', 'Hava kalitesi iyi.', Color(0xFF4ADE80));
    if (value <= 100) return const AqiLevel('Orta', 'Çok hassas kişiler dikkatli olmalı.', Color(0xFFFACC15));
    if (value <= 150) return const AqiLevel('Hassas gruplar için sağlıksız', 'Hassas gruplar efordan kaçınmalı.', Color(0xFFFB923C));
    if (value <= 200) return const AqiLevel('Sağlıksız', 'Dış mekân etkinliklerini azaltın.', Color(0xFFF87171));
    if (value <= 300) return const AqiLevel('Çok sağlıksız', 'Dış mekânda uzun süre kalmayın.', Color(0xFFC084FC));
    return const AqiLevel('Tehlikeli', 'Dış mekân etkinliklerinden kaçının.', Color(0xFFBE123C));
  }

  /// Ölçek üst sınırı (gösterge çubuğu için).
  static double max(AqiScale s) => s == AqiScale.european ? 100 : 300;
}
