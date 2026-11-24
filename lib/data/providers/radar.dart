import '../../core/failure.dart';
import '../../core/http.dart';

class RadarFrame {
  const RadarFrame({required this.time, required this.tileUrl, this.isForecast = false});

  /// UTC zaman damgası (radar taramasının gerçek zamanı).
  final DateTime time;
  final String tileUrl;

  /// Yalnızca kaynak gerçekten ileri tahmin karesi verirse true olur.
  final bool isForecast;
}

class RadarSet {
  const RadarSet({required this.frames, required this.generated, required this.maxNativeZoom});
  final List<RadarFrame> frames;

  /// Kaynağın listeyi ürettiği zaman (UTC).
  final DateTime generated;
  final int maxNativeZoom;

  bool get hasForecast => frames.any((f) => f.isForecast);
  RadarFrame? get latestObserved => frames.where((f) => !f.isForecast).lastOrNull;
}

/// RainViewer Weather Maps API — kişisel/eğitim amaçlı ücretsiz, anahtarsız.
/// 2026 itibarıyla ücretsiz katmanda: son ~2 saatlik geçmiş kareler, en fazla
/// zoom 7, ileri tahmin (nowcast) ve uydu verisi yok. Kaynak tahmin karesi
/// göndermezse uygulama tahmin karesi ÜRETMEZ.
class RainViewerProvider {
  const RainViewerProvider();

  static const source = 'RainViewer';
  static const endpoint = 'https://api.rainviewer.com/public/weather-maps.json';
  static const maxNativeZoom = 7;

  Future<RadarSet> fetch() async {
    final j = await Http.getJson(endpoint, source: source) as Map<String, dynamic>;
    return parse(j);
  }

  static RadarSet parse(Map<String, dynamic> j) {
    final host = j['host'] as String?;
    final radar = j['radar'];
    if (host == null || radar is! Map) {
      throw const AppFailure(FailureKind.invalidResponse, source: source);
    }
    List<RadarFrame> read(Object? list, bool forecast) => [
          if (list is List)
            for (final f in list.whereType<Map>())
              if (f['time'] is num && f['path'] is String)
                RadarFrame(
                  time: DateTime.fromMillisecondsSinceEpoch((f['time'] as num).toInt() * 1000, isUtc: true),
                  tileUrl: '$host${f['path']}/256/{z}/{x}/{y}/2/1_1.png',
                  isForecast: forecast,
                ),
        ];
    final frames = [...read(radar['past'], false), ...read(radar['nowcast'], true)]
      ..sort((a, b) => a.time.compareTo(b.time));
    if (frames.isEmpty) throw const AppFailure(FailureKind.server, source: source, detail: 'kare yok');
    return RadarSet(
      frames: frames,
      generated: DateTime.fromMillisecondsSinceEpoch(((j['generated'] as num?) ?? 0).toInt() * 1000, isUtc: true),
      maxNativeZoom: maxNativeZoom,
    );
  }
}
