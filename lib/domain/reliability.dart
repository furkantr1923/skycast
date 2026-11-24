import 'dart:ui';

/// Tahmin güvenilirliği. 15 günlük tahmin kısa vadeli tahminle aynı güvende
/// değildir; arayüz bunu açıkça belirtir.
enum Reliability { high, medium, low }

extension ReliabilityX on Reliability {
  String get label => switch (this) {
        Reliability.high => 'Yüksek güven',
        Reliability.medium => 'Orta güven',
        Reliability.low => 'Düşük güven · eğilim',
      };

  Color get color => switch (this) {
        Reliability.high => const Color(0xFF4ADE80),
        Reliability.medium => const Color(0xFFFACC15),
        Reliability.low => const Color(0xFFFB923C),
      };

  /// [dayIndex]: 0 = bugün.
  static Reliability forDay(int dayIndex) {
    if (dayIndex <= 2) return Reliability.high;
    if (dayIndex <= 6) return Reliability.medium;
    return Reliability.low;
  }
}
