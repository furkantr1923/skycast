import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/weather_code.dart';

/// Hava durumuna ve gece/gündüze göre değişen atmosferik arka plan.
///
/// Performans: parçacık sayısı düşük, tek bir CustomPainter, RepaintBoundary
/// içinde; animasyon kapalıysa yalnızca gradyan çizilir.
class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground({super.key, required this.code, required this.isDay, required this.animate, this.child});

  final int? code;
  final bool isDay;
  final bool animate;
  final Widget? child;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AtmosphereBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final kind = WeatherCode.kind(widget.code);
    final hasParticles = kind != SkyKind.cloudy && kind != SkyKind.partly || !widget.isDay;
    if (widget.animate && hasParticles) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = WeatherCode.kind(widget.code);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 900),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: palette(kind, widget.isDay),
            ),
          ),
        ),
        if (widget.animate && !reduce)
          RepaintBoundary(
            child: CustomPaint(painter: _ParticlePainter(_c, kind, widget.isDay)),
          ),
        if (widget.child != null) widget.child!,
      ],
    );
  }

  static List<Color> palette(SkyKind kind, bool day) {
    if (!day) {
      return switch (kind) {
        SkyKind.clear => const [Color(0xFF0B1636), Color(0xFF070C1C), Color(0xFF050811)],
        SkyKind.thunder || SkyKind.hail => const [Color(0xFF1A1530), Color(0xFF0B0A18), Color(0xFF050509)],
        SkyKind.snow => const [Color(0xFF1B2438), Color(0xFF0D1322), Color(0xFF060911)],
        _ => const [Color(0xFF141B2C), Color(0xFF0A0F1B), Color(0xFF05080F)],
      };
    }
    return switch (kind) {
      SkyKind.clear => const [Color(0xFF1C5FA8), Color(0xFF113866), Color(0xFF07152A)],
      SkyKind.partly => const [Color(0xFF2B5D93), Color(0xFF173656), Color(0xFF081426)],
      SkyKind.cloudy => const [Color(0xFF3B4B63), Color(0xFF1F2A3B), Color(0xFF0A0F19)],
      SkyKind.fog => const [Color(0xFF4A5566), Color(0xFF283040), Color(0xFF0C1018)],
      SkyKind.drizzle || SkyKind.rain || SkyKind.freezingRain => const [Color(0xFF26364E), Color(0xFF151F31), Color(0xFF070B14)],
      SkyKind.snow => const [Color(0xFF52637D), Color(0xFF2A3549), Color(0xFF0D121C)],
      SkyKind.thunder || SkyKind.hail => const [Color(0xFF2A2A45), Color(0xFF16162A), Color(0xFF07070F)],
    };
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter(this.anim, this.kind, this.isDay) : super(repaint: anim);

  final Animation<double> anim;
  final SkyKind kind;
  final bool isDay;

  static final _rnd = math.Random(7);
  static final _seeds = List.generate(90, (_) => (_rnd.nextDouble(), _rnd.nextDouble(), _rnd.nextDouble()));

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    switch (kind) {
      case SkyKind.rain || SkyKind.drizzle || SkyKind.freezingRain || SkyKind.thunder || SkyKind.hail:
        final n = kind == SkyKind.drizzle ? 40 : 75;
        final p = Paint()
          ..strokeWidth = kind == SkyKind.drizzle ? 1 : 1.3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < n; i++) {
          final s = _seeds[i];
          final speed = 14 + s.$3 * 10;
          final y = ((s.$2 + t * speed) % 1.0) * (size.height + 60) - 30;
          final x = s.$1 * size.width + y * 0.12;
          p.color = Colors.white.withValues(alpha: 0.10 + s.$3 * 0.18);
          final len = kind == SkyKind.drizzle ? 8.0 : 16 + s.$3 * 10;
          canvas.drawLine(Offset(x, y), Offset(x - len * 0.12, y - len), p);
        }
        if (kind == SkyKind.thunder || kind == SkyKind.hail) {
          final phase = (t * 20) % 1.0;
          if (phase < 0.025) {
            canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.10));
          }
        }
      case SkyKind.snow:
        final p = Paint();
        for (var i = 0; i < 60; i++) {
          final s = _seeds[i];
          final y = ((s.$2 + t * (2 + s.$3 * 2)) % 1.0) * (size.height + 20) - 10;
          final x = s.$1 * size.width + math.sin((t * 6 + s.$3) * math.pi * 2) * 12;
          p.color = Colors.white.withValues(alpha: 0.35 + s.$3 * 0.4);
          canvas.drawCircle(Offset(x, y), 1.4 + s.$3 * 2.2, p);
        }
      case SkyKind.fog:
        final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
        for (var i = 0; i < 4; i++) {
          final s = _seeds[i];
          final x = ((s.$1 + t * (0.6 + s.$3)) % 1.4 - 0.2) * size.width;
          p.color = Colors.white.withValues(alpha: 0.05);
          canvas.drawOval(Rect.fromCenter(center: Offset(x, size.height * (0.25 + s.$2 * 0.5)), width: size.width * 0.9, height: 110), p);
        }
      case SkyKind.clear || SkyKind.partly || SkyKind.cloudy:
        if (!isDay) {
          final p = Paint();
          for (var i = 0; i < 70; i++) {
            final s = _seeds[i];
            final tw = 0.5 + 0.5 * math.sin((t * 8 + s.$3 * 10) * math.pi);
            p.color = Colors.white.withValues(alpha: (kind == SkyKind.clear ? 0.55 : 0.25) * (0.3 + 0.7 * tw) * s.$3);
            canvas.drawCircle(Offset(s.$1 * size.width, s.$2 * size.height * 0.6), 0.6 + s.$3 * 1.1, p);
          }
        }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.kind != kind || old.isDay != isDay;
}
