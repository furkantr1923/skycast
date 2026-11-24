import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/weather_code.dart';

/// Vektör olarak çizilen hava durumu simgeleri (bağımlılık yok, her boyutta keskin).
class WeatherIcon extends StatelessWidget {
  const WeatherIcon({super.key, required this.code, this.isDay = true, this.size = 40});

  final int? code;
  final bool isDay;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        label: WeatherCode.describe(code),
        child: CustomPaint(size: Size.square(size), painter: _IconPainter(WeatherCode.kind(code), isDay, code ?? -1)),
      );
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.kind, this.isDay, this.code);

  final SkyKind kind;
  final bool isDay;
  final int code;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    canvas.save();
    canvas.scale(s / 100);
    switch (kind) {
      case SkyKind.clear:
        isDay ? _sun(canvas, const Offset(50, 50), 22) : _moon(canvas, const Offset(50, 50), 26);
      case SkyKind.partly:
        isDay ? _sun(canvas, const Offset(36, 36), 16) : _moon(canvas, const Offset(36, 34), 18);
        _cloud(canvas, const Offset(56, 62), 1.0, const Color(0xFFE8EEF8));
      case SkyKind.cloudy:
        _cloud(canvas, const Offset(40, 44), 0.75, const Color(0xFF8E9BB2));
        _cloud(canvas, const Offset(54, 60), 1.0, const Color(0xFFD9E1EE));
      case SkyKind.fog:
        _cloud(canvas, const Offset(50, 42), 0.9, const Color(0xFFB9C3D4));
        final p = Paint()
          ..color = const Color(0xFFCBD5E1)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final y = 66.0 + i * 10;
          canvas.drawLine(Offset(22 + i * 6, y), Offset(80 - i * 4, y), p);
        }
      case SkyKind.drizzle:
        _cloud(canvas, const Offset(50, 42), 1.0, const Color(0xFFC9D3E3));
        _drops(canvas, 3, small: true);
      case SkyKind.rain:
        _cloud(canvas, const Offset(50, 42), 1.0, const Color(0xFFB4C0D4));
        _drops(canvas, code == 65 || code == 82 ? 4 : 3);
      case SkyKind.freezingRain:
        _cloud(canvas, const Offset(50, 42), 1.0, const Color(0xFFB4C0D4));
        _drops(canvas, 2);
        _flake(canvas, const Offset(66, 80), 7);
      case SkyKind.snow:
        _cloud(canvas, const Offset(50, 42), 1.0, const Color(0xFFDCE4F0));
        _flake(canvas, const Offset(34, 78), 7);
        _flake(canvas, const Offset(52, 86), 7);
        _flake(canvas, const Offset(70, 76), 7);
      case SkyKind.thunder:
        _cloud(canvas, const Offset(50, 40), 1.0, const Color(0xFF7D8AA3));
        _bolt(canvas);
        _drops(canvas, 2, offsetX: -14);
      case SkyKind.hail:
        _cloud(canvas, const Offset(50, 40), 1.0, const Color(0xFF7D8AA3));
        _bolt(canvas);
        final hp = Paint()..color = const Color(0xFFE0F2FE);
        canvas.drawCircle(const Offset(30, 80), 4.5, hp);
        canvas.drawCircle(const Offset(72, 84), 4.5, hp);
    }
    canvas.restore();
  }

  void _sun(Canvas c, Offset o, double r) {
    final glow = Paint()
      ..shader = RadialGradient(colors: [const Color(0x66FFC861), const Color(0x00FFC861)])
          .createShader(Rect.fromCircle(center: o, radius: r * 2.2));
    c.drawCircle(o, r * 2.2, glow);
    final ray = Paint()
      ..color = const Color(0xFFFFC14D)
      ..strokeWidth = r * 0.16
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(o + Offset(math.cos(a), math.sin(a)) * r * 1.35, o + Offset(math.cos(a), math.sin(a)) * r * 1.75, ray);
    }
    c.drawCircle(
      o,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE08A), Color(0xFFFFA62B)],
        ).createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _moon(Canvas c, Offset o, double r) {
    final path = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: o, radius: r)),
      Path()..addOval(Rect.fromCircle(center: o + Offset(r * 0.55, -r * 0.35), radius: r * 0.85)),
    );
    c.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(colors: [Color(0xFFF5F0D8), Color(0xFFC9C2A0)])
            .createShader(Rect.fromCircle(center: o, radius: r)),
    );
  }

  void _cloud(Canvas c, Offset o, double k, Color color) {
    final p = Path()
      ..addOval(Rect.fromCircle(center: o + Offset(-16 * k, 4 * k), radius: 13 * k))
      ..addOval(Rect.fromCircle(center: o + Offset(0, -6 * k), radius: 18 * k))
      ..addOval(Rect.fromCircle(center: o + Offset(17 * k, 3 * k), radius: 14 * k))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(o.dx - 29 * k, o.dy, o.dx + 31 * k, o.dy + 17 * k),
        Radius.circular(9 * k),
      ));
    c.drawPath(p.shift(const Offset(0, 2.5)), Paint()..color = const Color(0x33000000));
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, Colors.white, 0.35)!, color],
        ).createShader(Rect.fromCircle(center: o, radius: 30 * k)),
    );
  }

  void _drops(Canvas c, int n, {bool small = false, double offsetX = 0}) {
    final p = Paint()
      ..color = const Color(0xFF60B8FF)
      ..strokeWidth = small ? 3.5 : 4.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final x = 30.0 + offsetX + i * (40 / math.max(1, n - 1)) * (n == 1 ? 0 : 1);
      final y = 70.0 + (i.isEven ? 0 : 7);
      c.drawLine(Offset(x + 3, y), Offset(x - 2, y + (small ? 9 : 14)), p);
    }
  }

  void _flake(Canvas c, Offset o, double r) {
    final p = Paint()
      ..color = const Color(0xFFE0F2FE)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final a = i * math.pi / 3;
      final d = Offset(math.cos(a), math.sin(a)) * r;
      c.drawLine(o - d, o + d, p);
    }
  }

  void _bolt(Canvas c) {
    final path = Path()
      ..moveTo(54, 54)
      ..lineTo(42, 74)
      ..lineTo(52, 74)
      ..lineTo(46, 92)
      ..lineTo(64, 68)
      ..lineTo(54, 68)
      ..lineTo(60, 54)
      ..close();
    c.drawPath(path, Paint()..color = const Color(0xFFFFD24D));
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) => old.kind != kind || old.isDay != isDay || old.code != code;
}
