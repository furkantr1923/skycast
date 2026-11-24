import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/failure.dart';
import '../data/storage/local_store.dart';
import '../data/weather_repository.dart';
import '../domain/alert.dart';
import '../domain/alert_engine.dart';
import '../domain/place.dart';
import '../domain/weather.dart';
import '../services/location_service.dart';
import 'load.dart';

enum GpsStatus { unknown, locating, ok, denied, disabled, failed }

/// Uygulamanın tek durum kaynağı. Ekranlar bu denetleyiciyi dinler.
///
/// Arka planda zamanlayıcı, yoklama ya da bildirim servisi YOKTUR: veri
/// yalnızca açılışta, konum değişince ve kullanıcı "Yenile" deyince alınır.
class AppController extends ChangeNotifier {
  AppController({
    required this.repo,
    required this.store,
    this.location = const LocationService(),
    this.alertEngine = const AlertEngine(),
  });

  final WeatherRepository repo;
  final LocalStore? store;
  final LocationService location;
  final AlertEngine alertEngine;

  AppSettings settings = const AppSettings();
  List<Place> favorites = [];
  Place? place;
  Place? gpsPlace;
  GpsStatus gps = GpsStatus.unknown;
  AppFailure? gpsFailure;

  Load<Forecast> forecast = const Load.idle();
  Load<AirQuality> air = const Load.idle();
  Load<List<WeatherAlert>> official = const Load.idle();
  List<WeatherAlert> indicators = const [];
  List<WeatherAlert> history = [];

  bool initialized = false;
  int _requestId = 0;

  /// Açılış: tercihleri yükle, GPS'i dene; olmazsa son konum ya da şehir araması.
  Future<void> init({Place? overridePlace}) async {
    if (store != null) {
      settings = store!.loadSettings();
      favorites = store!.loadFavorites();
      history = store!.loadHistory();
    }
    initialized = true;
    notifyListeners();
    if (overridePlace != null) {
      await select(overridePlace);
      return;
    }
    if (settings.useGps) {
      final ok = await locate();
      if (ok) return;
    }
    final last = store?.loadLastPlace() ?? (favorites.isNotEmpty ? favorites.first : null);
    if (last != null) await select(last);
  }

  bool get needsPlace => initialized && place == null && gps != GpsStatus.locating;

  /// GPS ile konum bulur; başarılıysa o konumu seçer.
  Future<bool> locate() async {
    gps = GpsStatus.locating;
    gpsFailure = null;
    notifyListeners();
    try {
      final pos = await location.current();
      Place p;
      try {
        p = await repo.placeAt(pos.lat, pos.lon, isGps: true);
      } on AppFailure catch (f) {
        if (f.kind != FailureKind.offline) rethrow;
        p = Place(name: 'Konumum', latitude: pos.lat, longitude: pos.lon, isGps: true);
      }
      gpsPlace = p.copyWith(isGps: true);
      gps = GpsStatus.ok;
      await select(gpsPlace!);
      return true;
    } on AppFailure catch (f) {
      gpsFailure = f;
      gps = switch (f.kind) {
        FailureKind.permissionDenied => GpsStatus.denied,
        FailureKind.locationDisabled => GpsStatus.disabled,
        _ => GpsStatus.failed,
      };
      notifyListeners();
      return false;
    }
  }

  Future<void> select(Place p) async {
    place = p;
    if (!p.isGps) unawaited(store?.saveLastPlace(p));
    notifyListeners();
    await refresh(force: false);
  }

  /// Seçili konum için tüm verileri getirir. [force] önbelleği atlar.
  Future<void> refresh({bool force = true}) async {
    final p = place;
    if (p == null) return;
    final id = ++_requestId;
    forecast = const Load.loading();
    air = const Load.loading();
    official = const Load.loading();
    indicators = const [];
    notifyListeners();

    final fFuture = repo.forecast(p, force: force);
    final aFuture = repo.air(p, force: force);
    final oFuture = repo.officialAlerts(p, force: force);

    try {
      final f = await fFuture;
      if (id != _requestId) return;
      forecast = Load.ready(f);
      indicators = alertEngine.evaluate(f, p.name);
    } catch (e) {
      if (id != _requestId) return;
      forecast = Load.error(AppFailure.from(e));
    }
    notifyListeners();

    try {
      final a = await aFuture;
      if (id == _requestId) air = Load.ready(a);
    } catch (e) {
      if (id == _requestId) air = Load.error(AppFailure.from(e));
    }
    try {
      final o = await oFuture;
      if (id == _requestId) official = Load.ready(o);
    } catch (e) {
      if (id == _requestId) official = Load.error(AppFailure.from(e));
    }
    if (id != _requestId) return;
    _recordHistory([...?official.data, ...indicators]);
    notifyListeners();
  }

  List<WeatherAlert> get activeAlerts => [...?official.data, ...indicators];

  void _recordHistory(List<WeatherAlert> alerts) {
    if (alerts.isEmpty) return;
    final known = history.map((a) => a.id).toSet();
    final now = DateTime.now();
    final fresh = alerts.where((a) => !known.contains(a.id)).map((a) => a.withFirstSeen(now)).toList();
    if (fresh.isEmpty) return;
    history = [...fresh, ...history].take(LocalStore.historyLimit).toList();
    unawaited(store?.saveHistory(history));
  }

  Future<void> clearHistory() async {
    history = [];
    await store?.saveHistory(history);
    notifyListeners();
  }

  bool isFavorite(Place p) => favorites.contains(p);

  Future<void> toggleFavorite(Place p) async {
    if (isFavorite(p)) {
      favorites = favorites.where((f) => f != p).toList();
    } else {
      favorites = [...favorites, p.copyWith(isGps: false)];
    }
    notifyListeners();
    await store?.saveFavorites(favorites);
  }

  Future<void> reorderFavorites(int oldIndex, int newIndex) async {
    final list = [...favorites];
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    favorites = list;
    notifyListeners();
    await store?.saveFavorites(favorites);
  }

  Future<void> updateSettings(AppSettings s) async {
    settings = s;
    notifyListeners();
    await store?.saveSettings(s);
  }
}
