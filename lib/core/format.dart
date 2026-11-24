import 'package:intl/intl.dart';

/// Türkçe biçimlendirme yardımcıları. Birimler sabittir: °C, km/sa, mm, hPa.
class Fmt {
  Fmt._();

  static final _one = NumberFormat('0.#', 'tr_TR');
  static final _int = NumberFormat('0', 'tr_TR');

  static String temp(double? v) => v == null ? '—' : '${_int.format(v.round())}°';
  static String tempC(double? v) => v == null ? '—' : '${_int.format(v.round())} °C';
  static String wind(double? v) => v == null ? '—' : '${_int.format(v.round())} km/sa';
  static String mm(double? v) => v == null ? '—' : '${_one.format(v)} mm';
  static String cm(double? v) => v == null ? '—' : '${_one.format(v)} cm';
  static String hpa(double? v) => v == null ? '—' : '${_int.format(v.round())} hPa';
  static String pct(num? v) => v == null ? '—' : '%${_int.format(v.round())}';
  static String km(double? meters) {
    if (meters == null) return '—';
    if (meters >= 10000) return '${_int.format(meters / 1000)} km';
    return '${_one.format(meters / 1000)} km';
  }

  static String num1(double? v) => v == null ? '—' : _one.format(v);
  static String num0(num? v) => v == null ? '—' : _int.format(v);

  static String hm(DateTime t) => DateFormat('HH:mm', 'tr_TR').format(t);
  static String hour(DateTime t) => DateFormat('HH', 'tr_TR').format(t);
  static String dayShort(DateTime t) => DateFormat('EEE', 'tr_TR').format(t);
  static String dayLong(DateTime t) => DateFormat('EEEE', 'tr_TR').format(t);
  static String dayMonth(DateTime t) => DateFormat('d MMM', 'tr_TR').format(t);
  static String fullDate(DateTime t) => DateFormat('d MMMM y, EEEE', 'tr_TR').format(t);
  static String dateTime(DateTime t) => DateFormat('d MMM HH:mm', 'tr_TR').format(t);

  /// "3 dk önce" gibi göreli süre.
  static String ago(DateTime t, {DateTime? now}) {
    final d = (now ?? DateTime.now()).difference(t);
    if (d.inSeconds < 60) return 'az önce';
    if (d.inMinutes < 60) return '${d.inMinutes} dk önce';
    if (d.inHours < 24) return '${d.inHours} sa önce';
    return '${d.inDays} gün önce';
  }

  static String coord(double lat, double lon) =>
      '${lat.abs().toStringAsFixed(2)}° ${lat >= 0 ? 'K' : 'G'}, ${lon.abs().toStringAsFixed(2)}° ${lon >= 0 ? 'D' : 'B'}';
}
