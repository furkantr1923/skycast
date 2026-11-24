import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:skycast/core/failure.dart';
import 'package:skycast/data/providers/meteoalarm.dart';
import 'package:skycast/data/providers/open_meteo_air.dart';
import 'package:skycast/data/providers/open_meteo_forecast.dart';
import 'package:skycast/data/weather_repository.dart';
import 'package:skycast/domain/alert.dart';
import 'package:skycast/domain/place.dart';
import 'package:skycast/domain/weather.dart';
import 'package:skycast/state/app_controller.dart';

import 'fixtures.dart';

class FakeForecast extends OpenMeteoForecastProvider {
  FakeForecast(this.mode);
  String mode;
  int calls = 0;

  @override
  Future<Forecast> fetch(double lat, double lon) async {
    calls++;
    if (mode == 'offline') throw const AppFailure(FailureKind.offline, source: 'test');
    return OpenMeteoForecastProvider.parse(forecastJson(rainDay0: mode == 'storm' ? 45 : 0));
  }
}

class FailingAir extends OpenMeteoAirProvider {
  const FailingAir();
  @override
  Future<AirQuality> fetch(double lat, double lon) async => throw const AppFailure(FailureKind.server, source: 'test');
}

class NoAlarm extends MeteoAlarmProvider {
  const NoAlarm();
  @override
  Future<List<WeatherAlert>> fetch(Place place) async => throw const AppFailure(FailureKind.notSupported);
}

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));
  const p = Place(name: 'İstanbul', latitude: 41, longitude: 29, countryCode: 'TR');

  AppController make(FakeForecast f) => AppController(
        repo: WeatherRepository(forecastProvider: f, airProvider: const FailingAir(), alarmProvider: const NoAlarm()),
        store: null,
      );

  test('Bir kaynağın hatası diğerlerini etkilemez', () async {
    final c = make(FakeForecast('ok'));
    await c.select(p);
    expect(c.forecast.hasData, isTrue);
    expect(c.air.hasError, isTrue);
    expect(c.official.failure?.kind, FailureKind.notSupported);
  });

  test('Bağlantı yoksa eski veri güncelmiş gibi gösterilmez', () async {
    final f = FakeForecast('ok');
    final c = make(f);
    await c.select(p);
    expect(c.forecast.hasData, isTrue);
    f.mode = 'offline';
    await c.refresh(force: true);
    expect(c.forecast.hasError, isTrue);
    expect(c.forecast.data, isNull);
    expect(c.forecast.failure!.kind, FailureKind.offline);
    expect(c.indicators, isEmpty);
  });

  test('Önbellek gereksiz isteği önler, Yenile önbelleği atlar', () async {
    final f = FakeForecast('ok');
    final c = make(f);
    await c.select(p);
    await c.select(p);
    expect(f.calls, 1);
    await c.refresh(force: true);
    expect(f.calls, 2);
  });

  test('Göstergeler üretilir ve geçmişe yazılır', () async {
    final c = make(FakeForecast('storm'));
    await c.select(p);
    expect(c.indicators.any((a) => a.type == AlertType.heavyRain), isTrue);
    expect(c.history, isNotEmpty);
    final n = c.history.length;
    await c.refresh(force: true);
    expect(c.history.length, n, reason: 'aynı uyarı geçmişe iki kez yazılmaz');
  });

  test('Favoriler eklenir ve çıkarılır', () async {
    final c = make(FakeForecast('ok'));
    await c.toggleFavorite(p);
    expect(c.isFavorite(p), isTrue);
    await c.toggleFavorite(p);
    expect(c.favorites, isEmpty);
  });
}
