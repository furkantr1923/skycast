import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../data/providers/grid.dart';
import '../../data/providers/radar.dart';
import '../maps/map_common.dart';
import '../maps/timeline.dart';
import '../maps/weather_map_screen.dart';
import '../shell.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';

/// Animasyonlu yağış radarı (RainViewer). Kareler gerçek tarama zamanıyla
/// etiketlenir; kaynak ileri tahmin vermiyorsa tahmin karesi gösterilmez.
class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key, this.embedded = false});
  final bool embedded;

  /// Haritayı belirli bir noktaya taşımak için (ör. öz-sınamada radar kapsamı olan bölge).
  static final requestedCenter = ValueNotifier<(LatLng, double)?>(null);

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> {
  final _map = MapController();
  RadarSet? _set;
  AppFailure? _error;
  bool _loading = false;
  int _index = 0;
  LatLng? _tapped;

  @override
  void initState() {
    super.initState();
    RadarScreen.requestedCenter.addListener(_onCenter);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onCenter() {
    final r = RadarScreen.requestedCenter.value;
    if (r == null) return;
    _map.move(r.$1, r.$2);
    RadarScreen.requestedCenter.value = null;
  }

  @override
  void dispose() {
    RadarScreen.requestedCenter.removeListener(_onCenter);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await AppScope.read(context).repo.radar(force: force);
      if (!mounted) return;
      setState(() {
        _set = s;
        final latest = s.frames.lastIndexWhere((f) => !f.isForecast);
        _index = latest < 0 ? s.frames.length - 1 : latest;
      });
    } catch (e) {
      if (mounted) setState(() => _error = AppFailure.from(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _inWindow(int i, int n) {
    final d = (i - _index + n) % n;
    return d <= 2;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final center = placeLatLng(c.place);
    final s = _set;
    final top = MediaQuery.paddingOf(context).top;
    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 5.5,
        minZoom: 2,
        maxZoom: 10,
        interactionOptions: kInteraction,
        backgroundColor: Sky.bg,
        onTap: (tap, point) {
          setState(() => _tapped = point);
          showPointWeather(context, point);
        },
      ),
      children: [
        baseLayer(),
        if (s != null)
          for (var i = 0; i < s.frames.length; i++)
            // Seçili kare ile sonraki iki kare önceden yüklenir (titremesiz animasyon,
            // düşük bellek); diğer kareler ağaçta tutulmaz.
            if (_inWindow(i, s.frames.length)) Opacity(
              key: ValueKey(s.frames[i].tileUrl),
              opacity: i == _index ? 0.85 : 0.0,
              child: TileLayer(
                urlTemplate: s.frames[i].tileUrl,
                userAgentPackageName: kUserAgentPackage,
                maxNativeZoom: s.maxNativeZoom,
                tileDisplay: const TileDisplay.instantaneous(),
              ),
            ),
        MarkerLayer(markers: [
          if (c.place != null) placeMarker(center),
          if (_tapped != null) placeMarker(_tapped!, color: Sky.warm),
        ]),
      ],
    );

    return Stack(children: [
      Positioned.fill(child: map),
      Positioned(
        top: widget.embedded ? 8 : top + 6,
        left: 10,
        right: 10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!widget.embedded)
            Container(
              decoration: BoxDecoration(color: const Color(0xE60B1324), borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: const PlaceTitle(prefix: 'Radar'),
            ),
          const SizedBox(height: 8),
          if (s != null)
            Wrap(spacing: 6, runSpacing: 6, children: [
              const Pill('GEÇMİŞ TARAMALAR · canlı değil', color: Sky.warm, icon: Icons.history_rounded),
              Pill('Kaynak güncellemesi ${Fmt.hm(s.generated.toLocal())}', color: Sky.textDim, icon: Icons.sync_rounded),
              if (!s.hasForecast) const Pill('İleri radar tahmini kaynakta yok', color: Sky.textDim, icon: Icons.block_rounded),
            ]),
        ]),
      ),
      Positioned(right: 12, top: widget.embedded ? 60 : top + 110, child: ZoomButtons(controller: _map, onLocate: () => _map.move(center, 7))),
      Positioned(
        left: 10,
        right: 10,
        bottom: widget.embedded ? 12 : 92,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_loading && s == null) const GlassCard(child: LoadingView(label: 'Radar kareleri alınıyor…')),
              if (_error != null)
                FailureView(
                  failure: _error!,
                  compact: true,
                  feature: 'Yağış radarı',
                  onRetry: () => _load(force: true),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: () {
                    WeatherMapScreen.requestedLayer.value = const MapLayer.grid(GridVariable.precipitation);
                    ShellNav.of(context).open(Dest.maps);
                  },
                  icon: const Icon(Icons.grid_on_rounded),
                  label: const Text('Model yağış haritasını aç (radar değil)'),
                ),
              ],
              if (s != null) ...[
                FrameTimeline(
                  count: s.frames.length,
                  index: _index,
                  frameMs: c.settings.radarFrameMs,
                  onChanged: (i) => setState(() => _index = i),
                  labelFor: (i) => '${Fmt.hm(s.frames[i].time.toLocal())} · ${Fmt.ago(s.frames[i].time)}',
                  tagFor: (i) => s.frames[i].isForecast ? 'TAHMİN' : (i == s.frames.lastIndexWhere((f) => !f.isForecast) ? 'EN SON' : null),
                  subtitle: 'Saatler cihaz saatinizle gösterilir · tarama tarihi ${Fmt.dayMonth(s.frames[_index].time.toLocal())}',
                ),
                const SizedBox(height: 6),
                const MapAttribution('Radar: RainViewer.com · ücretsiz katmanda en fazla 7. yakınlaştırma  · © OpenStreetMap katkıcıları'),
                const SizedBox(height: 4),
                const MapAttribution('Radar kapsaması ülkelerin paylaştığı veriye bağlıdır; bazı bölgelerde radar verisi bulunmayabilir.'),
              ],
            ]),
          ),
        ),
      ),
    ]);
  }
}
