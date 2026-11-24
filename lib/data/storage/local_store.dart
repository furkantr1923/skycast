import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/alert.dart';
import '../../domain/aqi.dart';
import '../../domain/place.dart';

class AppSettings {
  const AppSettings({
    this.aqiScale = AqiScale.european,
    this.animatedBackground = true,
    this.useGps = true,
    this.radarFrameMs = 700,
  });

  final AqiScale aqiScale;

  /// Atmosferik arka plan animasyonları (kapatılırsa sabit gradyan kullanılır).
  final bool animatedBackground;

  /// Açılışta GPS konumu denensin mi?
  final bool useGps;

  /// Radar/uydu animasyonunda kare süresi.
  final int radarFrameMs;

  AppSettings copyWith({AqiScale? aqiScale, bool? animatedBackground, bool? useGps, int? radarFrameMs}) => AppSettings(
        aqiScale: aqiScale ?? this.aqiScale,
        animatedBackground: animatedBackground ?? this.animatedBackground,
        useGps: useGps ?? this.useGps,
        radarFrameMs: radarFrameMs ?? this.radarFrameMs,
      );

  Map<String, dynamic> toJson() => {
        'aqi': aqiScale.name,
        'anim': animatedBackground,
        'gps': useGps,
        'radarMs': radarFrameMs,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        aqiScale: AqiScale.values.firstWhere((e) => e.name == j['aqi'], orElse: () => AqiScale.european),
        animatedBackground: j['anim'] as bool? ?? true,
        useGps: j['gps'] as bool? ?? true,
        radarFrameMs: (j['radarMs'] as num?)?.toInt() ?? 700,
      );
}

/// Yerel depolama: yalnızca tercihler, favoriler, son seçilen konum ve uyarı
/// geçmişi tutulur. Hava durumu verisi KALICI OLARAK saklanmaz.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<LocalStore> open() async => LocalStore(await SharedPreferences.getInstance());

  static const _kSettings = 'settings.v1';
  static const _kFavorites = 'favorites.v1';
  static const _kLast = 'lastPlace.v1';
  static const _kHistory = 'alertHistory.v1';
  static const historyLimit = 300;

  AppSettings loadSettings() {
    final s = _prefs.getString(_kSettings);
    if (s == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) => _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  List<Place> loadFavorites() {
    final s = _prefs.getString(_kFavorites);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).map((e) => Place.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveFavorites(List<Place> list) =>
      _prefs.setString(_kFavorites, jsonEncode(list.map((p) => p.toJson()).toList()));

  Place? loadLastPlace() {
    final s = _prefs.getString(_kLast);
    if (s == null) return null;
    try {
      return Place.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastPlace(Place p) => _prefs.setString(_kLast, jsonEncode(p.toJson()));

  List<WeatherAlert> loadHistory() {
    final s = _prefs.getString(_kHistory);
    if (s == null) return [];
    try {
      return (jsonDecode(s) as List).map((e) => WeatherAlert.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<WeatherAlert> list) => _prefs.setString(
        _kHistory,
        jsonEncode(list.take(historyLimit).map((a) => a.toJson()).toList()),
      );
}
