import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../data/providers/grid.dart';
import '../../domain/wind.dart';
import '../maps/weather_map_screen.dart';
import '../shell.dart';
import '../widgets/common.dart';

/// Ayrıntılı rüzgâr: pusula, hız, hamle, Beaufort ve saatlik değişim.
class WindScreen extends StatelessWidget {
  const WindScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (c.forecast.hasError) return FailureView(failure: c.forecast.failure!, onRetry: () => c.refresh(force: true));
    final f = c.forecast.data;
    if (f == null) return const LoadingView();
    final cur = f.current;
    final bft = Wind.beaufort(cur.windSpeed);
    final hours = f.upcomingHours(24);
    final maxV = hours.map((h) => math.max(h.windGusts ?? 0, h.windSpeed ?? 0)).fold<double>(10, math.max);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GlassCard(
          child: Row(
            children: [
              SizedBox(width: 150, height: 150, child: CustomPaint(painter: _Compass(cur.windDirection))),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Fmt.wind(cur.windSpeed), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
                    Text('${Wind.directionName(cur.windDirection)} yönünden (${Fmt.num0(cur.windDirection?.round())}°)', style: Sky.small),
                    const SizedBox(height: 12),
                    Text('Hamle ${Fmt.wind(cur.windGusts)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Pill('Beaufort $bft · ${Wind.beaufortName(bft)}', color: _bftColor(bft)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Sky.gap),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Saatlik rüzgâr · 24 saat', icon: Icons.air_rounded),
              SizedBox(
                height: 190,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: hours.length,
                  itemBuilder: (_, i) {
                    final h = hours[i];
                    final sp = (h.windSpeed ?? 0) / maxV;
                    final gs = (h.windGusts ?? 0) / maxV;
                    return SizedBox(
                      width: 44,
                      child: Column(
                        children: [
                          Text(Fmt.num0(h.windSpeed?.round()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Expanded(
                            child: Stack(alignment: Alignment.bottomCenter, children: [
                              FractionallySizedBox(
                                heightFactor: gs.clamp(0.02, 1.0),
                                child: Container(width: 14, decoration: BoxDecoration(color: const Color(0x44FCA5A5), borderRadius: BorderRadius.circular(4))),
                              ),
                              FractionallySizedBox(
                                heightFactor: sp.clamp(0.02, 1.0),
                                child: Container(width: 14, decoration: BoxDecoration(color: _bftColor(Wind.beaufort(h.windSpeed)), borderRadius: BorderRadius.circular(4))),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 6),
                          WindArrow(degrees: h.windDirection, size: 16),
                          Text(Fmt.hour(h.time), style: Sky.tiny),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 6),
              const Text('Dolu çubuk: ortalama rüzgâr · soluk çubuk: hamle · ok: rüzgârın estiği yön', style: Sky.tiny),
            ],
          ),
        ),
        const SizedBox(height: Sky.gap),
        FilledButton.tonalIcon(
          onPressed: () {
            WeatherMapScreen.requestedLayer.value = MapLayer.grid(GridVariable.wind);
            ShellNav.of(context).open(Dest.maps);
          },
          icon: const Icon(Icons.map_rounded),
          label: const Text('Animasyonlu rüzgâr haritasını aç'),
        ),
        const SizedBox(height: Sky.gap),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Beaufort ölçeği', icon: Icons.table_rows_rounded),
              for (var b = 0; b <= 12; b++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  decoration: BoxDecoration(
                    color: b == bft ? _bftColor(b).withValues(alpha: 0.18) : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    SizedBox(width: 26, child: Text('$b', style: TextStyle(fontWeight: FontWeight.w700, color: _bftColor(b)))),
                    Expanded(child: Text(Wind.beaufortName(b))),
                    Text(_range(b), style: Sky.small),
                  ]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SourceNote('Veri: Open-Meteo.com (CC BY 4.0) · 10 m yükseklik'),
      ],
    );
  }

  static String _range(int b) {
    const l = [0, 1, 6, 12, 20, 29, 39, 50, 62, 75, 89, 103, 118];
    if (b == 12) return '≥ 118 km/sa';
    return '${l[b]}–${l[b + 1] - 1} km/sa';
  }

  static Color _bftColor(int b) {
    if (b <= 2) return const Color(0xFF7DD3FC);
    if (b <= 4) return const Color(0xFF6EE7B7);
    if (b <= 6) return const Color(0xFFFDE047);
    if (b <= 8) return const Color(0xFFFB923C);
    return const Color(0xFFEF4444);
  }
}

class _Compass extends CustomPainter {
  _Compass(this.deg);
  final double? deg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    canvas.drawCircle(c, r, Paint()..color = Sky.surface);
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..color = Sky.stroke
      ..strokeWidth = 1.5);
    final tick = Paint()
      ..color = Sky.textFaint
      ..strokeWidth = 1.4;
    for (var i = 0; i < 36; i++) {
      final a = i * math.pi / 18 - math.pi / 2;
      final inner = i % 9 == 0 ? r - 12 : r - 6;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * inner, c + Offset(math.cos(a), math.sin(a)) * r, tick);
    }
    const labels = ['K', 'D', 'G', 'B'];
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: i == 0 ? Sky.accent : Sky.textDim, fontSize: 13, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(math.cos(a), math.sin(a)) * (r - 24) - Offset(tp.width / 2, tp.height / 2));
    }
    if (deg == null) return;
    // Ok rüzgârın gittiği yönü gösterir.
    final a = (deg! + 180) * math.pi / 180 - math.pi / 2;
    final dir = Offset(math.cos(a), math.sin(a));
    final perp = Offset(-dir.dy, dir.dx);
    final tip = c + dir * (r - 30);
    final tail = c - dir * (r - 30);
    canvas.drawLine(tail, tip, Paint()
      ..color = Sky.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    final head = Path()
      ..moveTo(tip.dx + dir.dx * 8, tip.dy + dir.dy * 8)
      ..lineTo(tip.dx - dir.dx * 8 + perp.dx * 8, tip.dy - dir.dy * 8 + perp.dy * 8)
      ..lineTo(tip.dx - dir.dx * 8 - perp.dx * 8, tip.dy - dir.dy * 8 - perp.dy * 8)
      ..close();
    canvas.drawPath(head, Paint()..color = Sky.accent);
    canvas.drawCircle(c, 5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _Compass old) => old.deg != deg;
}
