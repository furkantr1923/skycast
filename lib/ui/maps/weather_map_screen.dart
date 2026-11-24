import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../data/providers/grid.dart';
import '../../data/providers/satellite.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';
import 'map_common.dart';

/// Harita katmanı: model ızgarası (yağış, bulut, sıcaklık, rüzgâr, basınç) ya da uydu.
class MapLayer {
  const MapLayer._(this.grid);
  const MapLayer.grid(GridVariable v) : this._(v);
  const MapLayer.satellite() : this._(null);

  final GridVariable? grid;
  bool get isSatellite => grid == null;

  String get label => grid?.label ?? 'Uydu';

  @override
  bool operator ==(Object other) => other is MapLayer && other.grid == grid;

  @override
  int get hashCode => grid.hashCode;

  static const all = [
    MapLayer.grid(GridVariable.precipitation),
    MapLayer.grid(GridVariable.cloud),
    MapLayer.grid(GridVariable.temperature),
    MapLayer.grid(GridVariable.wind),
    MapLayer.grid(GridVariable.pressure),
    MapLayer.satellite(),
  ];
}

/// Meteorolojik haritalar. Haritaya dokunmak o noktayı seçer ve hava durumunu gösterir.
class WeatherMapScreen extends StatefulWidget {
  const WeatherMapScreen({super.key, this.embedded = false});
  final bool embedded;

  /// Başka ekranlardan (ör. Rüzgâr) belirli bir katmanla açmak için.
  static final requestedLayer = ValueNotifier<MapLayer?>(null);

  @override
  State<WeatherMapScreen> createState() => _WeatherMapScreenState();
}

class _WeatherMapScreenState extends State<WeatherMapScreen> with SingleTickerProviderStateMixin {
  final _map = MapController();
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  MapLayer _layer = const MapLayer.grid(GridVariable.temperature);
  GridField? _grid;
  Uint8List? _image;
  GridVariable? _imageVar;
  AppFailure? _error;
  bool _loading = false;
  Timer? _debounce;
  LatLng? _tapped;
  bool _ready = false;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WeatherMapScreen.requestedLayer.addListener(_onRequested);
  }

  void _onRequested() {
    final l = WeatherMapScreen.requestedLayer.value;
    if (l != null && mounted) {
      setState(() => _layer = l);
      WeatherMapScreen.requestedLayer.value = null;
      _render();
    }
  }

  @override
  void dispose() {
    WeatherMapScreen.requestedLayer.removeListener(_onRequested);
    _debounce?.cancel();
    _anim.dispose();
    super.dispose();
  }

  void _scheduleFetch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), _fetch);
  }

  Future<void> _fetch() async {
    if (!_ready || !mounted || _layer.isSatellite) return;
    final b = _map.camera.visibleBounds;
    final latPad = (b.north - b.south) * 0.08, lonPad = (b.east - b.west) * 0.08;
    final south = (b.south - latPad).clamp(-80.0, 80.0), north = (b.north + latPad).clamp(-80.0, 80.0);
    final west = (b.west - lonPad).clamp(-180.0, 180.0), east = (b.east + lonPad).clamp(-180.0, 180.0);
    final id = ++_seq;
    setState(() => _loading = true);
    try {
      final g = await AppScope.read(context).repo.grid(south: south, north: north, west: west, east: east);
      if (!mounted || id != _seq) return;
      _grid = g;
      _error = null;
      await _render();
    } catch (e) {
      if (!mounted || id != _seq) return;
      setState(() => _error = AppFailure.from(e));
    } finally {
      if (mounted && id == _seq) setState(() => _loading = false);
    }
  }

  Future<void> _render() async {
    final g = _grid, v = _layer.grid;
    if (g == null || v == null) {
      setState(() {});
      if (v != null && g == null) _fetch();
      return;
    }
    final bytes = await renderField(g, v);
    if (!mounted) return;
    setState(() {
      _image = bytes;
      _imageVar = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final center = placeLatLng(c.place);
    final g = _grid;
    final v = _layer.grid;
    final children = <Widget>[
      baseLayer(),
      if (_layer.isSatellite)
        TileLayer(
          wmsOptions: WMSTileLayerOptions(
            baseUrl: SatelliteCatalog.eumetsatWms,
            layers: const ['mtg_fd:ir105_hrfi'],
            format: 'image/png',
            transparent: true,
            version: '1.3.0',
          ),
          userAgentPackageName: kUserAgentPackage,
          maxNativeZoom: 9,
        )
      else if (_image != null && g != null && _imageVar == v)
        OverlayImageLayer(overlayImages: [
          OverlayImage(
            bounds: LatLngBounds(LatLng(g.south, g.west), LatLng(g.north, g.east)),
            imageProvider: MemoryImage(_image!),
          ),
        ]),
      if (!_layer.isSatellite && g != null && v != null) MarkerLayer(markers: _valueMarkers(g, v)),
      MarkerLayer(markers: [
        if (c.place != null) placeMarker(center),
        if (_tapped != null) placeMarker(_tapped!, color: Sky.warm),
      ]),
    ];

    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 5.5,
        minZoom: 2,
        maxZoom: 11,
        interactionOptions: kInteraction,
        backgroundColor: Sky.bg,
        onMapReady: () {
          _ready = true;
          _fetch();
        },
        onPositionChanged: (camera, hasGesture) => _scheduleFetch(),
        onTap: (tap, point) {
          setState(() => _tapped = point);
          showPointWeather(context, point);
        },
      ),
      children: children,
    );

    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(child: map),
        Positioned(
          top: (widget.embedded ? 8 : top + 6),
          left: 10,
          right: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.embedded)
                Container(
                  decoration: BoxDecoration(color: const Color(0xE60B1324), borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: const PlaceTitle(prefix: 'Harita'),
                ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final l in MapLayer.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l.label),
                        selected: _layer == l,
                        backgroundColor: const Color(0xE60B1324),
                        onSelected: (_) {
                          setState(() => _layer = l);
                          _render();
                        },
                      ),
                    ),
                ]),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2)),
                ),
              if (_error != null && !_layer.isSatellite)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(width: 340, child: FailureView(failure: _error!, compact: true, feature: '${_layer.label} katmanı', onRetry: _fetch)),
                ),
            ],
          ),
        ),
        Positioned(
          right: 12,
          bottom: widget.embedded ? 16 : 100,
          child: ZoomButtons(controller: _map, onLocate: () => _map.move(center, 7)),
        ),
        Positioned(
          left: 10,
          bottom: widget.embedded ? 16 : 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v != null) FieldLegend(variable: v),
              if (_layer.isSatellite) const MapAttribution('MTG-I1 kızılötesi 10,5 µm · en son görüntü'),
              const SizedBox(height: 6),
              MapAttribution(_attribution(g)),
            ],
          ),
        ),
      ],
    );
  }

  String _attribution(GridField? g) {
    if (_layer.isSatellite) return '© EUMETSAT  · © OpenStreetMap katkıcıları';
    final t = g == null ? '' : ' · model ${Fmt.hm(g.time.toLocal())}';
    return 'Open-Meteo$t  · © OpenStreetMap katkıcıları';
  }

  List<Marker> _valueMarkers(GridField g, GridVariable v) {
    final out = <Marker>[];
    for (var r = 0; r < g.rows; r++) {
      for (var col = 0; col < g.cols; col++) {
        final i = r * g.cols + col;
        final val = g.values[v]![i];
        if (val == null) continue;
        final p = LatLng(g.latAt(r), g.lonAt(col));
        if (v == GridVariable.wind) {
          final d = g.windDirection[i];
          if (d == null) continue;
          out.add(Marker(point: p, width: 46, height: 46, child: WindGlyph(speed: val, direction: d, anim: _anim)));
          if ((r + col).isEven) {
            out.add(Marker(point: p, width: 44, height: 16, alignment: const Alignment(0, 2.6), child: Center(child: _label(Fmt.num0(val.round())))));
          }
        } else if ((r + col).isEven) {
          final text = switch (v) {
            GridVariable.temperature => Fmt.temp(val),
            GridVariable.pressure => Fmt.num0(val.round()),
            GridVariable.cloud => Fmt.pct(val),
            GridVariable.precipitation => val >= 0.1 ? Fmt.num1(val) : '',
            GridVariable.wind => '',
          };
          if (text.isEmpty) continue;
          out.add(Marker(point: p, width: 52, height: 22, child: Center(child: _label(text))));
        }
      }
    }
    return out;
  }

  Widget _label(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xAA060A13), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
}
