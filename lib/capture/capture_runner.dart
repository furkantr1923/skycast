import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../app/platform.dart';
import '../core/failure.dart';
import '../core/http.dart';
import '../data/providers/grid.dart';
import '../data/providers/open_meteo_forecast.dart';
import '../data/providers/satellite.dart';
import '../domain/place.dart';
import '../state/app_controller.dart';
import '../ui/maps/weather_map_screen.dart';
import '../ui/shell.dart';

/// Öz-sınama ve ekran görüntüsü modu ayarları.
class CaptureConfig {
  const CaptureConfig({this.directory});

  /// Windows: görüntülerin ve raporun yazılacağı klasör. Android: null
  /// (görüntüler CI tarafından `adb screencap` ile, log işaretlerine göre alınır).
  final String? directory;

  static const _androidFlag = bool.fromEnvironment('SKYCAST_CAPTURE');

  static CaptureConfig? fromArgs(List<String> args) {
    for (final a in args) {
      if (a.startsWith('--capture=')) return CaptureConfig(directory: a.substring('--capture='.length));
    }
    if (_androidFlag) return const CaptureConfig();
    return null;
  }
}

/// Uygulamayı GERÇEK verilerle gezer, her ekranın görüntüsünü alır ve tüm veri
/// kaynaklarını sınayıp rapor üretir. CI'da derlenen uygulama üzerinde çalışır.
class CaptureRunner {
  CaptureRunner({required this.config, required this.controller, required this.shellKey, required this.boundaryKey});

  final CaptureConfig config;
  final AppController controller;
  final GlobalKey<AppShellState> shellKey;
  final GlobalKey boundaryKey;
  final _report = StringBuffer();
  int _step = 0;

  static const istanbul = Place(
    name: 'İstanbul',
    latitude: 41.0082,
    longitude: 28.9784,
    region: 'İstanbul',
    country: 'Türkiye',
    countryCode: 'TR',
  );

  void _log(String line) {
    _report.writeln(line);
    debugPrint('SKYCAST_SELFTEST $line');
  }

  Future<void> run() async {
    final started = DateTime.now();
    _log('SKYCAST öz-sınama · ${DateTime.now().toUtc().toIso8601String()} · ${Platform.operatingSystem}');
    await controller.init(overridePlace: istanbul);
    await _waitFor(() => controller.forecast.hasData || controller.forecast.hasError, const Duration(seconds: 40));
    _log('Açılıştan ilk veriye: ${DateTime.now().difference(started).inMilliseconds} ms');
    await Future<void>.delayed(const Duration(seconds: 2));

    final desktop = AppPlatform.isDesktop;
    final steps = <(String, VoidCallback, int)>[
      ('panel', () => _open(Dest.today), 3),
      ('saatlik', () => _open(Dest.hourly), 2),
      ('gunluk_15', () => _open(Dest.daily), 2),
      ('grafikler', () => _open(Dest.charts), 3),
      ('harita_sicaklik', () => _open(Dest.maps), 9),
      ('harita_ruzgar', () {
        WeatherMapScreen.requestedLayer.value = const MapLayer.grid(GridVariable.wind);
        _open(Dest.maps);
      }, 7),
      ('harita_yagis', () {
        WeatherMapScreen.requestedLayer.value = const MapLayer.grid(GridVariable.precipitation);
        _open(Dest.maps);
      }, 6),
      ('radar', () => _open(Dest.radar), 10),
      ('uydu', () => _open(Dest.satellite), 12),
      if (!desktop) ('ruzgar', () => _open(Dest.wind), 2),
      if (!desktop) ('hava_kalitesi', () => _open(Dest.air), 2),
      ('uyarilar', () => _open(Dest.alerts), 2),
      ('konumlar', () => _open(Dest.places), 2),
      if (!desktop) ('daha_fazla', () => _openTab(4), 2),
      ('ayarlar', () => _open(Dest.settings), 2),
      if (!desktop) ('hakkinda', () => _open(Dest.about), 2),
    ];
    for (final s in steps) {
      try {
        s.$2();
        await Future<void>.delayed(Duration(seconds: s.$3));
        await _shot(s.$1);
      } catch (e) {
        _log('EKRAN ${s.$1}: HATA $e');
      }
    }
    _open(Dest.today);

    await _selfTest();

    // Bağlantı yok senaryosu: GERÇEK bir bağlantı hatası (kapalı port) üretilir.
    try {
      final original = controller.repo.forecastProvider;
      controller.repo.forecastProvider = const OpenMeteoForecastProvider(endpoint: 'https://127.0.0.1:9/v1/forecast');
      controller.repo.clearCache();
      await controller.refresh(force: true);
      final ok = controller.forecast.hasError && controller.forecast.data == null;
      _log('${ok ? 'OK  ' : 'FAIL'} Bağlantı yok davranışı: ${controller.forecast.failure?.kind} · eski veri gösterilmiyor=${controller.forecast.data == null}');
      await Future<void>.delayed(const Duration(seconds: 2));
      await _shot('baglanti_yok');
      controller.repo.forecastProvider = original;
    } catch (e) {
      _log('FAIL Bağlantı yok senaryosu: $e');
    }

    _log('Toplam süre: ${DateTime.now().difference(started).inSeconds} sn');
    if (config.directory != null) {
      await File('${config.directory}${Platform.pathSeparator}selftest.txt').writeAsString(_report.toString());
      exit(0);
    } else {
      debugPrint('SKYCAST_CAPTURE done');
    }
  }

  void _open(Dest d) => shellKey.currentState?.open(d);
  void _openTab(int i) => shellKey.currentState?.openTab(i);

  Future<void> _waitFor(bool Function() cond, Duration timeout) async {
    final end = DateTime.now().add(timeout);
    while (!cond() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
  }

  Future<void> _shot(String name) async {
    _step++;
    final id = '${_step.toString().padLeft(2, '0')}_$name';
    if (config.directory == null) {
      // Android: CI bu işareti görünce adb screencap alır.
      debugPrint('SKYCAST_CAPTURE step=$id');
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    await File('${config.directory}${Platform.pathSeparator}$id.png').writeAsBytes(bytes!.buffer.asUint8List());
    _log('EKRAN $id kaydedildi');
  }

  Future<void> _check(String name, Future<String> Function() body) async {
    final sw = Stopwatch()..start();
    try {
      final detail = await body();
      _log('OK   $name (${sw.elapsedMilliseconds} ms): $detail');
    } catch (e) {
      final f = AppFailure.from(e);
      _log('FAIL $name (${sw.elapsedMilliseconds} ms): ${f.kind} ${f.source ?? ''} ${f.detail ?? ''}');
    }
  }

  Future<void> _selfTest() async {
    final repo = controller.repo;
    _log('--- Veri kaynakları ---');
    await _check('Open-Meteo tahmin', () async {
      final f = await repo.forecast(istanbul, force: true);
      if (f.daily.length < 15) throw AppFailure(FailureKind.invalidResponse, detail: '${f.daily.length} gün');
      return '${f.hourly.length} saat, ${f.daily.length} gün, şu an ${f.current.temperature} °C, ${f.clock.timezone}';
    });
    await _check('Open-Meteo hava kalitesi', () async {
      final a = await repo.air(istanbul, force: true);
      return 'EAQI ${a.europeanAqi}, US AQI ${a.usAqi}, model ${a.time}';
    });
    await _check('Şehir arama (Çorum)', () async {
      final r = await repo.search('Çorum');
      if (r.isEmpty) throw const AppFailure(FailureKind.invalidResponse, detail: 'sonuç yok');
      return '${r.length} sonuç, ilk: ${r.first.name} / ${r.first.region}';
    });
    await _check('Ters konum (Nominatim)', () async {
      final p = await repo.placeAt(40.5489, 34.9533);
      return '${p.name}, ${p.region}, ${p.country}';
    });
    await _check('RainViewer radar', () async {
      final s = await repo.radar(force: true);
      final latest = s.latestObserved!;
      final tile = latest.tileUrl.replaceAll('{z}', '4').replaceAll('{x}', '9').replaceAll('{y}', '6');
      final code = await Http.status(tile);
      if (code != 200) throw AppFailure(FailureKind.server, detail: 'tile HTTP $code');
      return '${s.frames.length} kare (tahmin karesi: ${s.frames.where((f) => f.isForecast).length}), son ${latest.time.toIso8601String()}, döşeme HTTP $code';
    });
    for (final l in SatelliteCatalog.layers) {
      await _check('Uydu: ${l.name}', () async {
        final frames = await repo.satelliteFrames(l, const Duration(hours: 2), force: true);
        final f = frames.last;
        final url = l.kind == SatelliteKind.wmts
            ? l.wmtsTemplate!.replaceAll('{time}', f.dateOnly).replaceAll('{z}', '3').replaceAll('{y}', '2').replaceAll('{x}', '4')
            : '${l.wmsBase}service=WMS&request=GetMap&version=1.3.0&layers=${l.wmsLayer}&styles=&format=image/png&transparent=true'
                '&crs=EPSG:3857&width=256&height=256&bbox=2504688,4383204,5009377,6887893&time=${f.wmsTime}';
        final code = await Http.status(url);
        if (code != 200) throw AppFailure(FailureKind.server, detail: 'HTTP $code');
        return '${frames.length} kare, son ${f.time.toIso8601String()}, görüntü HTTP $code';
      });
    }
    await _check('MeteoAlarm (Almanya, Berlin)', () async {
      final a = await repo.officialAlerts(const Place(name: 'Berlin', latitude: 52.52, longitude: 13.4, region: 'Berlin', countryCode: 'DE'), force: true);
      return '${a.length} eşleşen resmî uyarı';
    });
    await _check('MeteoAlarm (Türkiye)', () async {
      try {
        await repo.officialAlerts(istanbul, force: true);
        return 'beklenmedik şekilde yanıt verdi';
      } on AppFailure catch (f) {
        if (f.kind == FailureKind.notSupported) return 'kapsam dışı (beklenen) → uygulama bunu açıkça belirtir';
        rethrow;
      }
    });
    await _check('Harita ızgarası (Türkiye)', () async {
      final g = await repo.grid(south: 35, north: 43, west: 25, east: 45);
      final n = g.values[GridVariable.temperature]!.whereType<double>().length;
      return '${g.rows}x${g.cols} nokta, $n değer, model ${g.time.toIso8601String()}';
    });
    await _check('CARTO altlık', () async {
      final code = await Http.status('https://a.basemaps.cartocdn.com/dark_nolabels/4/9/6.png');
      if (code != 200) throw AppFailure(FailureKind.server, detail: 'HTTP $code');
      return 'HTTP $code';
    });
    _log('Uygulama göstergeleri (İstanbul, 3 gün): ${controller.indicators.length} adet');
  }
}
