import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../data/providers/grid.dart';
import '../../domain/place.dart';
import '../../domain/weather.dart';
import '../../domain/weather_code.dart';
import '../../domain/wind.dart';
import '../widgets/common.dart';
import '../widgets/weather_icon.dart';

const kUserAgentPackage = 'com.furkan.skycast';

/// CARTO koyu altlık (etiketsiz). Veri katmanları bunun üstüne çizilir.
TileLayer baseLayer() => TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_nolabels/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: kUserAgentPackage,
      maxNativeZoom: 18,
    );

/// Şehir/ülke etiketleri: veri katmanlarının ÜSTÜNDE, okunabilirlik için.
TileLayer labelsLayer() => TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c', 'd'],
      userAgentPackageName: kUserAgentPackage,
      maxNativeZoom: 18,
    );

const kInteraction = InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate);

LatLng placeLatLng(Place? p) => p == null ? const LatLng(39.0, 35.0) : LatLng(p.latitude, p.longitude);

class MapAttribution extends StatelessWidget {
  const MapAttribution(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: const Color(0xB3060A13), borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontSize: 10, color: Sky.textDim)),
      );
}

/// Yakınlaştırma düğmeleri (masaüstünde fare tekerleği de çalışır).
class ZoomButtons extends StatelessWidget {
  const ZoomButtons({super.key, required this.controller, this.onLocate});
  final MapController controller;
  final VoidCallback? onLocate;

  void _zoom(double d) {
    final cam = controller.camera;
    controller.move(cam.center, (cam.zoom + d).clamp(cam.minZoom ?? 2, cam.maxZoom ?? 18));
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.add_rounded, 'Yakınlaştır', () => _zoom(1)),
          const SizedBox(height: 6),
          _btn(Icons.remove_rounded, 'Uzaklaştır', () => _zoom(-1)),
          if (onLocate != null) ...[const SizedBox(height: 6), _btn(Icons.my_location_rounded, 'Seçili konuma git', onLocate!)],
        ],
      );

  Widget _btn(IconData i, String tip, VoidCallback onTap) => Material(
        color: const Color(0xE60B1324),
        shape: const CircleBorder(side: BorderSide(color: Sky.stroke)),
        child: IconButton(tooltip: tip, icon: Icon(i), onPressed: onTap),
      );
}

Marker placeMarker(LatLng p, {Color color = Sky.accent}) => Marker(
      point: p,
      width: 26,
      height: 26,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.3),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)],
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Izgara verisinden renkli katman üretimi
// ---------------------------------------------------------------------------

double _mercY(double lat) {
  final r = lat.clamp(-85.0, 85.0) * math.pi / 180;
  return math.log(math.tan(math.pi / 4 + r / 2));
}

double _invMercY(double y) => (2 * math.atan(math.exp(y)) - math.pi / 2) * 180 / math.pi;

/// Değer → renk (RGBA). Renk ölçekleri lejantla aynıdır.
class FieldPalette {
  FieldPalette._();

  static List<(double, Color)> stops(GridVariable v) => switch (v) {
        GridVariable.temperature => const [
            (-30, Color(0xFF7C3AED)), (-15, Color(0xFF3B82F6)), (0, Color(0xFF22D3EE)), (10, Color(0xFF4ADE80)), //
            (20, Color(0xFFFACC15)), (30, Color(0xFFF97316)), (40, Color(0xFFDC2626)),
          ],
        GridVariable.precipitation => const [
            (0.05, Color(0x0060A5FA)), (0.2, Color(0x9960A5FA)), (1, Color(0xCC2563EB)), (3, Color(0xDD22C55E)), //
            (6, Color(0xEEFACC15)), (12, Color(0xEEF97316)), (25, Color(0xFFDC2626)),
          ],
        GridVariable.cloud => const [(0, Color(0x00FFFFFF)), (30, Color(0x40E2E8F0)), (70, Color(0x99E2E8F0)), (100, Color(0xCCF8FAFC))],
        GridVariable.wind => const [
            (0, Color(0xFF1E3A8A)), (10, Color(0xFF0EA5E9)), (25, Color(0xFF14B8A6)), (40, Color(0xFF84CC16)), //
            (60, Color(0xFFFACC15)), (80, Color(0xFFF97316)), (110, Color(0xFFDC2626)),
          ],
        GridVariable.pressure => const [
            (980, Color(0xFF7C3AED)), (995, Color(0xFF3B82F6)), (1008, Color(0xFF22D3EE)), (1015, Color(0xFF4ADE80)), //
            (1022, Color(0xFFFACC15)), (1035, Color(0xFFF97316)),
          ],
      };

  static double alpha(GridVariable v) => switch (v) {
        GridVariable.precipitation || GridVariable.cloud => 1.0,
        _ => 0.55,
      };

  static Color? colorFor(GridVariable v, double? value) {
    if (value == null) return null;
    final s = stops(v);
    if (v == GridVariable.precipitation && value < s.first.$1) return null;
    if (value <= s.first.$1) return s.first.$2;
    if (value >= s.last.$1) return s.last.$2;
    for (var i = 0; i < s.length - 1; i++) {
      if (value <= s[i + 1].$1) {
        final t = (value - s[i].$1) / (s[i + 1].$1 - s[i].$1);
        return Color.lerp(s[i].$2, s[i + 1].$2, t);
      }
    }
    return s.last.$2;
  }
}

/// Izgarayı Web Mercator ile hizalı bir PNG'ye dönüştürür (OverlayImage için).
Future<Uint8List> renderField(GridField g, GridVariable v, {int width = 180, int height = 140}) async {
  final px = Uint8List(width * height * 4);
  final yN = _mercY(g.north), yS = _mercY(g.south);
  final a = FieldPalette.alpha(v);
  for (var r = 0; r < height; r++) {
    final lat = _invMercY(yN + (r + 0.5) / height * (yS - yN));
    for (var c = 0; c < width; c++) {
      final lon = g.west + (c + 0.5) / width * (g.east - g.west);
      final col = FieldPalette.colorFor(v, g.sample(v, lat, lon));
      final i = (r * width + c) * 4;
      if (col == null) continue;
      px[i] = (col.r * 255).round();
      px[i + 1] = (col.g * 255).round();
      px[i + 2] = (col.b * 255).round();
      px[i + 3] = (col.a * a * 255).round();
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(px, width, height, ui.PixelFormat.rgba8888, completer.complete);
  final img = await completer.future;
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  return bd!.buffer.asUint8List();
}

class FieldLegend extends StatelessWidget {
  const FieldLegend({super.key, required this.variable});
  final GridVariable variable;

  @override
  Widget build(BuildContext context) {
    final s = FieldPalette.stops(variable);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(color: const Color(0xE60B1324), borderRadius: BorderRadius.circular(12), border: Border.all(color: Sky.stroke)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${variable.label} (${variable.unit})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: 190,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: [for (final x in s) x.$2.withValues(alpha: 1)]),
            ),
          ),
          const SizedBox(height: 3),
          SizedBox(
            width: 190,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(Fmt.num1(s.first.$1), style: Sky.tiny),
              Text(Fmt.num1(s[s.length ~/ 2].$1), style: Sky.tiny),
              Text(Fmt.num1(s.last.$1), style: Sky.tiny),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Rüzgâr glifi: rüzgârın gittiği yöne akan çizgiler (animasyonlu).
class WindGlyph extends StatelessWidget {
  const WindGlyph({super.key, required this.speed, required this.direction, required this.anim});
  final double speed;
  final double direction;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WindGlyphPainter(speed, direction, anim));
}

class _WindGlyphPainter extends CustomPainter {
  _WindGlyphPainter(this.speed, this.dir, this.anim) : super(repaint: anim);
  final double speed, dir;
  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final a = (dir + 180 - 90) * math.pi / 180;
    final d = Offset(math.cos(a), math.sin(a));
    final p = Offset(-d.dy, d.dx);
    final len = size.width * 0.42;
    final col = FieldPalette.colorFor(GridVariable.wind, speed) ?? Colors.white;
    final rate = 0.4 + (speed / 40).clamp(0.0, 2.0);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    for (var k = -1; k <= 1; k++) {
      final phase = (anim.value * rate + k * 0.33) % 1.0;
      final off = p * (k * 6.0);
      final start = c + off - d * len + d * (2 * len * phase);
      final end = start + d * (len * 0.55);
      paint.color = Color.lerp(col, Colors.white, 0.35)!.withValues(alpha: (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.95);
      canvas.drawLine(start, end, paint);
    }
    final tip = c + d * len * 0.75;
    final head = Path()
      ..moveTo(tip.dx + d.dx * 5, tip.dy + d.dy * 5)
      ..lineTo(tip.dx - d.dx * 4 + p.dx * 4, tip.dy - d.dy * 4 + p.dy * 4)
      ..lineTo(tip.dx - d.dx * 4 - p.dx * 4, tip.dy - d.dy * 4 - p.dy * 4)
      ..close();
    canvas.drawPath(head, Paint()..color = Colors.white.withValues(alpha: 0.8));
  }

  @override
  bool shouldRepaint(covariant _WindGlyphPainter old) => old.speed != speed || old.dir != dir;
}

// ---------------------------------------------------------------------------
// Haritada dokunulan nokta için hava durumu
// ---------------------------------------------------------------------------

Future<void> showPointWeather(BuildContext context, LatLng point) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: Sky.bg2,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _PointSheet(point: point),
    );

class _PointSheet extends StatefulWidget {
  const _PointSheet({required this.point});
  final LatLng point;

  @override
  State<_PointSheet> createState() => _PointSheetState();
}

class _PointSheetState extends State<_PointSheet> {
  Place? _place;
  Forecast? _f;
  AppFailure? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = AppScope.read(context).repo;
    setState(() => _err = null);
    try {
      final lat = widget.point.latitude, lon = ((widget.point.longitude + 180) % 360) - 180;
      final results = await Future.wait([repo.placeAt(lat, lon), repo.forecast(Place(name: '', latitude: lat, longitude: lon))]);
      if (!mounted) return;
      setState(() {
        _place = results[0] as Place;
        _f = results[1] as Forecast;
      });
    } catch (e) {
      if (mounted) setState(() => _err = AppFailure.from(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Builder(builder: (context) {
          if (_err != null) return FailureView(failure: _err!, compact: true, onRetry: _load);
          final f = _f, p = _place;
          if (f == null || p == null) return const SizedBox(height: 160, child: LoadingView(label: 'Seçilen noktanın verisi alınıyor…'));
          final cur = f.current;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: Sky.title),
              Text([p.subtitle, Fmt.coord(p.latitude, p.longitude)].where((s) => s.isNotEmpty).join(' · '), style: Sky.small),
              const SizedBox(height: 14),
              Row(children: [
                WeatherIcon(code: cur.weatherCode, isDay: cur.isDay, size: 56),
                const SizedBox(width: 12),
                Text(Fmt.temp(cur.temperature), style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w300)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(WeatherCode.describe(cur.weatherCode), style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Hissedilen ${Fmt.temp(cur.apparentTemperature)}', style: Sky.small),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 8, children: [
                Text('Rüzgâr ${Fmt.wind(cur.windSpeed)} ${Wind.direction(cur.windDirection)}', style: Sky.small),
                Text('Hamle ${Fmt.wind(cur.windGusts)}', style: Sky.small),
                Text('Nem ${Fmt.pct(cur.humidity)}', style: Sky.small),
                Text('Basınç ${Fmt.hpa(cur.pressure)}', style: Sky.small),
                Text('Yağış ${Fmt.mm(cur.precipitation)}', style: Sky.small),
                Text('Bulut ${Fmt.pct(cur.cloudCover)}', style: Sky.small),
              ]),
              const SizedBox(height: 6),
              Text('Model zamanı ${Fmt.hm(cur.time)} (yerel) · Open-Meteo', style: Sky.tiny),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      c.select(p);
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Bu konumu seç'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: c.isFavorite(p) ? 'Favorilerden çıkar' : 'Favorilere ekle',
                  onPressed: () => c.toggleFavorite(p),
                  icon: Icon(c.isFavorite(p) ? Icons.star_rounded : Icons.star_outline_rounded),
                ),
              ]),
            ],
          );
        }),
      ),
    );
  }
}
