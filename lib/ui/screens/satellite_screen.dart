import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../data/providers/satellite.dart';
import '../maps/map_common.dart';
import '../maps/timeline.dart';
import '../widgets/common.dart';

/// Uydu görüntüleri: katman seçimi, geçmiş kareler ve bulut hareketi animasyonu.
class SatelliteScreen extends StatefulWidget {
  const SatelliteScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SatelliteScreen> createState() => _SatelliteScreenState();
}

class _SatelliteScreenState extends State<SatelliteScreen> {
  final _map = MapController();
  SatelliteLayer _layer = SatelliteCatalog.layers.first;
  Duration _span = const Duration(hours: 2);
  List<SatelliteFrame> _frames = const [];
  int _index = 0;
  AppFailure? _error;
  bool _loading = false;
  int _seq = 0;
  LatLng? _tapped;

  static const spans = [Duration(hours: 2), Duration(hours: 6), Duration(hours: 24), Duration(hours: 72)];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    final id = ++_seq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = await AppScope.read(context).repo.satelliteFrames(_layer, _span, force: force);
      if (!mounted || id != _seq) return;
      setState(() {
        _frames = f;
        _index = f.length - 1;
      });
    } catch (e) {
      if (mounted && id == _seq) {
        setState(() {
          _frames = const [];
          _error = AppFailure.from(e);
        });
      }
    } finally {
      if (mounted && id == _seq) setState(() => _loading = false);
    }
  }

  TileLayer _tileFor(SatelliteFrame f) {
    if (_layer.kind == SatelliteKind.wmts) {
      return TileLayer(
        urlTemplate: _layer.wmtsTemplate!.replaceAll('{time}', f.dateOnly),
        userAgentPackageName: kUserAgentPackage,
        maxNativeZoom: _layer.maxNativeZoom,
        tileDisplay: const TileDisplay.instantaneous(),
      );
    }
    return TileLayer(
      wmsOptions: WMSTileLayerOptions(
        baseUrl: _layer.wmsBase!,
        layers: [_layer.wmsLayer!],
        format: 'image/png',
        transparent: true,
        version: '1.3.0',
        otherParameters: {'time': f.wmsTime},
      ),
      userAgentPackageName: kUserAgentPackage,
      maxNativeZoom: _layer.maxNativeZoom,
      tileDisplay: const TileDisplay.instantaneous(),
    );
  }

  String _label(SatelliteFrame f) =>
      _layer.isDaily ? Fmt.fullDate(f.time) : '${Fmt.hm(f.time.toLocal())} · ${Fmt.dayMonth(f.time.toLocal())} · ${Fmt.ago(f.time)}';

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final center = placeLatLng(c.place);
    final map = FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 4.5,
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
        for (var i = 0; i < _frames.length; i++)
          Opacity(
            key: ValueKey('${_layer.id}:${_frames[i].wmsTime}'),
            opacity: i == _index ? 1.0 : 0.0,
            child: _tileFor(_frames[i]),
          ),
        labelsLayer(),
        MarkerLayer(markers: [
          if (c.place != null) placeMarker(center),
          if (_tapped != null) placeMarker(_tapped!, color: Sky.warm),
        ]),
      ],
    );

    return Stack(children: [
      Positioned.fill(child: map),
      Positioned(
        top: 8,
        left: 10,
        right: 10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final l in SatelliteCatalog.layers)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(l.name),
                    selected: _layer.id == l.id,
                    backgroundColor: const Color(0xE60B1324),
                    onSelected: (_) {
                      setState(() => _layer = l);
                      _load();
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          if (!_layer.isDaily)
            Wrap(spacing: 6, children: [
              for (final s in spans)
                ChoiceChip(
                  label: Text('Son ${s.inHours} sa'),
                  selected: _span == s,
                  backgroundColor: const Color(0xE60B1324),
                  onSelected: (_) {
                    setState(() => _span = s);
                    _load();
                  },
                ),
            ]),
          if (_loading) const Padding(padding: EdgeInsets.only(top: 8), child: SizedBox(width: 120, child: LinearProgressIndicator(minHeight: 2))),
        ]),
      ),
      Positioned(right: 12, top: 110, child: ZoomButtons(controller: _map, onLocate: () => _map.move(center, 6))),
      Positioned(
        left: 10,
        right: 10,
        bottom: 12,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (_error != null) FailureView(failure: _error!, compact: true, feature: _layer.name, onRetry: () => _load(force: true)),
              if (_frames.isNotEmpty)
                FrameTimeline(
                  count: _frames.length,
                  index: _index,
                  frameMs: c.settings.radarFrameMs,
                  onChanged: (i) => setState(() => _index = i),
                  labelFor: (i) => _label(_frames[i]),
                  tagFor: (i) => i == _frames.length - 1 ? 'EN SON' : 'GEÇMİŞ',
                  subtitle: _layer.description,
                ),
              const SizedBox(height: 6),
              MapAttribution('${_layer.attribution} · kapsama: ${_layer.coverage} · © OpenStreetMap · © CARTO'),
            ]),
          ),
        ),
      ),
    ]);
  }
}
