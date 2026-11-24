import '../../core/failure.dart';
import '../../core/http.dart';

enum SatelliteKind { wms, wmts }

/// Bir uydu görüntü katmanının tanımı.
class SatelliteLayer {
  const SatelliteLayer({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required this.attribution,
    required this.step,
    required this.coverage,
    this.wmsBase,
    this.wmsLayer,
    this.capabilitiesUrl,
    this.wmtsTemplate,
    this.maxNativeZoom = 9,
  });

  final String id;
  final String name;
  final String description;
  final SatelliteKind kind;
  final String attribution;

  /// Kareler arası zaman adımı.
  final Duration step;
  final String coverage;
  final String? wmsBase;
  final String? wmsLayer;
  final String? capabilitiesUrl;

  /// {time} yer tutuculu WMTS adresi.
  final String? wmtsTemplate;
  final int maxNativeZoom;

  bool get isDaily => step >= const Duration(days: 1);
}

class SatelliteFrame {
  const SatelliteFrame(this.time);

  /// UTC görüntü zamanı.
  final DateTime time;

  String get wmsTime => '${time.toIso8601String().substring(0, 19)}Z';
  String get dateOnly => time.toIso8601String().substring(0, 10);
}

/// Uydu katmanları: EUMETSAT EUMETView (Meteosat / MTG, WMS, zaman boyutlu)
/// ve NASA GIBS (günlük gerçek renk mozaik, WMTS). Her ikisi de anahtarsız ve
/// açık erişimlidir; atıf zorunludur.
class SatelliteCatalog {
  SatelliteCatalog._();

  static const eumetsatWms = 'https://view.eumetsat.int/geoserver/wms?';

  static const layers = <SatelliteLayer>[
    SatelliteLayer(
      id: 'mtg_ir',
      name: 'Bulut (Kızılötesi)',
      description: 'MTG-I1 FCI 10,5 µm kızılötesi. Gece ve gündüz bulutları gösterir; parlak alanlar soğuk ve yüksek bulutlardır.',
      kind: SatelliteKind.wms,
      wmsBase: eumetsatWms,
      wmsLayer: 'mtg_fd:ir105_hrfi',
      capabilitiesUrl: 'https://view.eumetsat.int/geoserver/mtg_fd/ir105_hrfi/ows?service=WMS&version=1.3.0&request=GetCapabilities',
      attribution: '© EUMETSAT (MTG-I1)',
      step: Duration(minutes: 10),
      coverage: 'Avrupa, Afrika, Orta Doğu, Atlantik',
    ),
    SatelliteLayer(
      id: 'mtg_geocolour',
      name: 'Renkli görünüm',
      description: 'MTG GeoColour: gündüz doğal renk, gece kızılötesi bulut görüntüsü.',
      kind: SatelliteKind.wms,
      wmsBase: eumetsatWms,
      wmsLayer: 'mtg_fd:rgb_geocolour',
      capabilitiesUrl: 'https://view.eumetsat.int/geoserver/mtg_fd/rgb_geocolour/ows?service=WMS&version=1.3.0&request=GetCapabilities',
      attribution: '© EUMETSAT (MTG-I1)',
      step: Duration(minutes: 10),
      coverage: 'Avrupa, Afrika, Orta Doğu, Atlantik',
    ),
    SatelliteLayer(
      id: 'msg_ir',
      name: 'Meteosat IR 10,8',
      description: 'Meteosat (MSG) SEVIRI 10,8 µm kızılötesi kanal, 15 dakikada bir.',
      kind: SatelliteKind.wms,
      wmsBase: eumetsatWms,
      wmsLayer: 'msg_fes:ir108',
      capabilitiesUrl: 'https://view.eumetsat.int/geoserver/msg_fes/ir108/ows?service=WMS&version=1.3.0&request=GetCapabilities',
      attribution: '© EUMETSAT (Meteosat)',
      step: Duration(minutes: 15),
      coverage: 'Avrupa, Afrika, Orta Doğu, Atlantik',
    ),
    SatelliteLayer(
      id: 'gibs_truecolor',
      name: 'Gerçek renk (günlük)',
      description: 'NASA MODIS Terra günlük gerçek renk mozaiği. Tüm dünya; günde bir görüntü.',
      kind: SatelliteKind.wmts,
      wmtsTemplate:
          'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/MODIS_Terra_CorrectedReflectance_TrueColor/default/{time}/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg',
      attribution: 'NASA EOSDIS GIBS / MODIS Terra',
      step: Duration(days: 1),
      coverage: 'Tüm dünya (günlük)',
      maxNativeZoom: 9,
    ),
  ];

  static SatelliteLayer byId(String id) => layers.firstWhere((l) => l.id == id, orElse: () => layers.first);
}

class SatelliteProvider {
  const SatelliteProvider();

  /// Katman için son kullanılabilir görüntü zamanını kaynaktan öğrenir ve
  /// geriye doğru [count] kare üretir. Zamanlar kaynağın gerçek adımıyla hizalıdır.
  Future<List<SatelliteFrame>> frames(SatelliteLayer layer, {int count = 12, Duration span = const Duration(hours: 2)}) async {
    if (layer.kind == SatelliteKind.wmts) {
      // GIBS günlük mozaik: bugünün mozaiği gün içinde tamamlanır; dün ve öncesi tamdır.
      final today = DateTime.now().toUtc();
      final base = DateTime.utc(today.year, today.month, today.day);
      return [for (var i = count; i >= 1; i--) SatelliteFrame(base.subtract(Duration(days: i)))];
    }
    final latest = await latestTime(layer);
    final stepCount = (span.inMinutes / layer.step.inMinutes).floor().clamp(1, 400);
    final every = (stepCount / (count - 1)).ceil().clamp(1, 400);
    final out = <SatelliteFrame>[];
    for (var i = 0; i <= stepCount; i += every) {
      out.add(SatelliteFrame(latest.subtract(layer.step * i)));
    }
    return out.reversed.toList();
  }

  Future<DateTime> latestTime(SatelliteLayer layer) async {
    final xml = await Http.getText(layer.capabilitiesUrl!, source: 'EUMETSAT');
    final t = parseLatest(xml);
    if (t == null) throw const AppFailure(FailureKind.invalidResponse, source: 'EUMETSAT', detail: 'zaman boyutu yok');
    return t;
  }

  /// GetCapabilities içindeki zaman boyutunun varsayılan (en son) değerini okur.
  static DateTime? parseLatest(String xml) {
    final dim = RegExp(r'<Dimension[^>]*name="time"[^>]*>([^<]*)<', caseSensitive: false).firstMatch(xml);
    final def = RegExp(r'<Dimension[^>]*name="time"[^>]*default="([^"]+)"', caseSensitive: false).firstMatch(xml);
    String? candidate = def?.group(1);
    if (candidate == null && dim != null) {
      final last = dim.group(1)!.split(',').last.trim();
      final parts = last.split('/');
      candidate = parts.length >= 2 ? parts[1] : parts.first;
    }
    if (candidate == null) return null;
    return DateTime.tryParse(candidate.trim())?.toUtc();
  }
}
