import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/platform.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/alert.dart';
import '../../domain/aqi.dart';
import '../../domain/reliability.dart';
import '../../domain/weather.dart';
import '../../domain/weather_code.dart';
import '../../domain/wind.dart';
import '../../state/app_controller.dart';
import '../../state/load.dart';
import '../shell.dart';
import '../widgets/atmosphere.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';
import '../widgets/weather_icon.dart';
import 'places_screen.dart';

/// Ana panel: anlık durum, saatlik şerit, ölçümler, AQI, uyarılar, 15 gün özeti.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final f = c.forecast.data;
    return AtmosphereBackground(
      code: f?.current.weatherCode,
      isDay: f?.isDay ?? true,
      animate: c.settings.animatedBackground,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
              child: Row(children: const [Expanded(child: Align(alignment: Alignment.centerLeft, child: PlaceTitle())), PlaceActions()]),
            ),
            Expanded(child: _body(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppController c) {
    if (c.place == null) {
      if (!c.initialized || c.gps == GpsStatus.locating) return const LoadingView(label: 'Konumunuz bulunuyor…');
      return const _Welcome();
    }
    if (c.forecast.hasError) {
      return FailureView(failure: c.forecast.failure!, onRetry: () => c.refresh(force: true));
    }
    final f = c.forecast.data;
    if (f == null) return const LoadingView();
    return RefreshIndicator(
      onRefresh: () => c.refresh(force: true),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 920;
        final pad = EdgeInsets.fromLTRB(16, 8, 16, AppPlatform.isDesktop ? 24 : 110);
        if (!wide) {
          return ListView(
            padding: pad,
            children: [
              _Hero(f: f),
              const SizedBox(height: 18),
              const _AlertStrip(),
              _HourlyStrip(f: f),
              const SizedBox(height: Sky.gap),
              _Metrics(f: f, columns: box.maxWidth > 560 ? 3 : 2),
              const SizedBox(height: Sky.gap),
              _SunCard(f: f),
              const SizedBox(height: Sky.gap),
              const _AqiCard(),
              const SizedBox(height: Sky.gap),
              _DailyPreview(f: f),
              const SizedBox(height: 18),
              _Footer(f: f),
            ],
          );
        }
        return SingleChildScrollView(
          padding: pad,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _Hero(f: f)),
                  const SizedBox(width: Sky.gap),
                  Expanded(flex: 4, child: Column(children: [const _AlertStrip(), const _AqiCard(), const SizedBox(height: Sky.gap), _SunCard(f: f)])),
                ],
              ),
              const SizedBox(height: Sky.gap),
              _HourlyStrip(f: f),
              const SizedBox(height: Sky.gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _Metrics(f: f, columns: 3)),
                  const SizedBox(width: Sky.gap),
                  Expanded(flex: 4, child: _DailyPreview(f: f)),
                ],
              ),
              const SizedBox(height: 18),
              _Footer(f: f),
            ],
          ),
        );
      }),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          children: [
            const SizedBox(height: 12),
            if (c.gpsFailure != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FailureView(failure: c.gpsFailure!, compact: true, onRetry: c.locate),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('Hava durumunu görmek istediğiniz şehri arayın', style: Sky.small, textAlign: TextAlign.center),
            ),
            const Expanded(child: PlaceSearchPanel(closeOnSelect: false)),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final cur = f.current;
    final today = f.today;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${Fmt.fullDate(f.clock.now())} · yerel saat ${Fmt.hm(f.clock.now())}', style: Sky.small),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(Fmt.temp(cur.temperature), style: Sky.h1),
                const SizedBox(width: 10),
                WeatherIcon(code: cur.weatherCode, isDay: cur.isDay, size: 96),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(WeatherCode.describe(cur.weatherCode), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              Text('Hissedilen ${Fmt.temp(cur.apparentTemperature)}', style: Sky.body.copyWith(color: Sky.textDim)),
              if (today != null) Text('En yüksek ${Fmt.temp(today.tempMax)}  ·  En düşük ${Fmt.temp(today.tempMin)}', style: Sky.body.copyWith(color: Sky.textDim)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pill('Ölçüm/model zamanı ${Fmt.hm(cur.time)}', color: Sky.accent, icon: Icons.schedule_rounded),
            Pill('Güncellendi ${Fmt.ago(f.fetchedAt)}', color: Sky.textDim, icon: Icons.sync_rounded),
          ]),
        ],
      ),
    );
  }
}

class _AlertStrip extends StatelessWidget {
  const _AlertStrip();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final alerts = c.activeAlerts.where((a) => a.severity != AlertSeverity.info).toList();
    if (alerts.isEmpty) return const SizedBox.shrink();
    final top = alerts.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sky.gap),
      child: GlassCard(
        color: top.severity.color.withValues(alpha: 0.12),
        onTap: () => ShellNav.of(context).open(Dest.alerts),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: top.severity.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${top.title} · ${top.severity.label}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    alerts.length > 1 ? '${top.originLabel} · +${alerts.length - 1} uyarı daha' : top.originLabel,
                    style: Sky.small,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Sky.textDim),
          ],
        ),
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  const _HourlyStrip({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final hours = f.upcomingHours(24);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            'Saatlik · önümüzdeki 24 saat',
            icon: Icons.schedule_rounded,
            trailing: TextButton(onPressed: () => ShellNav.of(context).open(Dest.hourly), child: const Text('Tümü')),
          ),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: hours.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (_, i) {
                final h = hours[i];
                return SizedBox(
                  width: 62,
                  child: Column(
                    children: [
                      Text(i == 0 ? 'Şimdi' : Fmt.hm(h.time), style: Sky.small),
                      const SizedBox(height: 6),
                      WeatherIcon(code: h.weatherCode, isDay: h.isDay, size: 34),
                      const SizedBox(height: 6),
                      Text(Fmt.temp(h.temperature), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        (h.precipitationProbability ?? 0) >= 10 ? Fmt.pct(h.precipitationProbability) : '',
                        style: const TextStyle(fontSize: 11.5, color: Sky.accent, fontWeight: FontWeight.w600),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          WindArrow(degrees: h.windDirection, size: 12, color: Sky.textFaint),
                          Text(Fmt.num0(h.windSpeed?.round()), style: Sky.tiny),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.f, required this.columns});
  final Forecast f;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final c = f.current;
    final bft = Wind.beaufort(c.windSpeed);
    final tiles = <_MetricData>[
      _MetricData(Icons.air_rounded, 'Rüzgâr', Fmt.wind(c.windSpeed), '${Wind.directionName(c.windDirection)} (${Wind.direction(c.windDirection)}) · $bft Bft',
          dir: c.windDirection, onTap: (ctx) => ShellNav.of(ctx).open(Dest.wind)),
      _MetricData(Icons.storm_rounded, 'Hamle', Fmt.wind(c.windGusts), Wind.beaufortName(Wind.beaufort(c.windGusts))),
      _MetricData(Icons.water_drop_outlined, 'Nem', Fmt.pct(c.humidity), 'Çiy noktası ${Fmt.tempC(c.dewPoint)}'),
      _MetricData(Icons.speed_rounded, 'Basınç', Fmt.hpa(c.pressure), 'Deniz seviyesi'),
      _MetricData(Icons.light_mode_outlined, 'UV indeksi', Fmt.num1(c.uvIndex), _uvLabel(c.uvIndex)),
      _MetricData(Icons.visibility_outlined, 'Görüş', Fmt.km(c.visibility), 'Yatay görüş mesafesi'),
      _MetricData(Icons.cloud_outlined, 'Bulut', Fmt.pct(c.cloudCover), 'Gökyüzü kapalılığı'),
      _MetricData(Icons.umbrella_outlined, 'Yağış', Fmt.mm(c.precipitation), 'Olasılık ${Fmt.pct(c.precipitationProbability)} · bugün ${Fmt.mm(f.today?.precipitationSum)}'),
      _MetricData(Icons.thermostat_rounded, 'Çiy noktası', Fmt.tempC(c.dewPoint), 'Hava bu sıcaklıkta doyar'),
    ];
    return LayoutBuilder(builder: (context, box) {
      final w = (box.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: _MetricTile(t))],
      );
    });
  }

  static String _uvLabel(double? uv) {
    if (uv == null) return 'Veri yok';
    if (uv < 3) return 'Düşük';
    if (uv < 6) return 'Orta';
    if (uv < 8) return 'Yüksek';
    if (uv < 11) return 'Çok yüksek';
    return 'Aşırı';
  }
}

class _MetricData {
  const _MetricData(this.icon, this.label, this.value, this.hint, {this.dir, this.onTap});
  final IconData icon;
  final String label, value, hint;
  final double? dir;
  final void Function(BuildContext)? onTap;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile(this.d);
  final _MetricData d;

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.all(14),
        onTap: d.onTap == null ? null : () => d.onTap!(context),
        child: SizedBox(
          height: 112,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(d.icon, size: 16, color: Sky.textDim),
                const SizedBox(width: 6),
                Expanded(child: Text(d.label, style: Sky.small)),
                if (d.dir != null) WindArrow(degrees: d.dir, size: 18),
              ]),
              const Spacer(),
              Text(d.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(d.hint, style: Sky.tiny, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _SunCard extends StatelessWidget {
  const _SunCard({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final d = f.today;
    if (d?.sunrise == null || d?.sunset == null) {
      return const GlassCard(child: Text('Gün doğumu/batımı verisi yok', style: Sky.small));
    }
    final now = f.clock.now();
    final total = d!.sunset!.difference(d.sunrise!).inMinutes;
    final t = (now.difference(d.sunrise!).inMinutes / math.max(1, total)).clamp(0.0, 1.0);
    final len = Duration(minutes: total);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Güneş', icon: Icons.wb_twilight_rounded),
          SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: _SunArc(t, now.isAfter(d.sunrise!) && now.isBefore(d.sunset!)))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _kv('Gün doğumu', Fmt.hm(d.sunrise!))),
              Expanded(child: _kv('Gün uzunluğu', '${len.inHours} sa ${len.inMinutes % 60} dk')),
              Expanded(child: _kv('Gün batımı', Fmt.hm(d.sunset!), end: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool end = false}) => Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [Text(k, style: Sky.tiny), const SizedBox(height: 2), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))],
      );
}

class _SunArc extends CustomPainter {
  _SunArc(this.t, this.up);
  final double t;
  final bool up;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, 8, size.width - 20, (size.height - 8) * 2);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Sky.stroke;
    canvas.drawArc(rect, math.pi, math.pi, false, track);
    final done = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [Color(0xFFFF9F43), Color(0xFFFFE08A)]).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi * t, false, done);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), track);
    if (up) {
      final a = math.pi + math.pi * t;
      final c = rect.center + Offset(math.cos(a) * rect.width / 2, math.sin(a) * rect.height / 2);
      canvas.drawCircle(c, 12, Paint()..color = const Color(0x55FFC861));
      canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFFFD27A));
    }
  }

  @override
  bool shouldRepaint(covariant _SunArc old) => old.t != t || old.up != up;
}

class _AqiCard extends StatelessWidget {
  const _AqiCard();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final scale = c.settings.aqiScale;
    final a = c.air;
    Widget content;
    if (a.isLoading || a.status == LoadStatus.idle) {
      content = const SizedBox(height: 60, child: LoadingView(label: 'Hava kalitesi alınıyor…'));
    } else if (a.hasError) {
      content = Text('Hava kalitesi (AQI) şu an kullanılamıyor · ${a.failure!.title}', style: Sky.small);
    } else {
      final aq = a.data!;
      final v = scale == AqiScale.european ? aq.europeanAqi : aq.usAqi;
      if (v == null) {
        content = const Text('Bu konum için AQI verisi yok.', style: Sky.small);
      } else {
        final lvl = Aqi.level(v, scale);
        final stale = DateTime.now().difference(aq.fetchedAt) > const Duration(hours: 2);
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.num0(v.round()), style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: lvl.color)),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(lvl.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (v / Aqi.max(scale)).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Sky.surfaceStrong,
                valueColor: AlwaysStoppedAnimation(lvl.color),
              ),
            ),
            const SizedBox(height: 8),
            Text(lvl.advice, style: Sky.small),
            const SizedBox(height: 4),
            Text('${Aqi.scaleName(scale)} · model saati ${Fmt.hm(aq.time)}${stale ? ' · ESKİ VERİ' : ''}', style: Sky.tiny),
          ],
        );
      }
    }
    return GlassCard(
      onTap: AppPlatform.isDesktop ? null : () => ShellNav.of(context).open(Dest.air),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SectionTitle('Hava kalitesi', icon: Icons.masks_outlined), content]),
    );
  }
}

class _DailyPreview extends StatelessWidget {
  const _DailyPreview({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final days = f.daily.take(15).toList();
    final lo = days.map((d) => d.tempMin ?? 99).fold<double>(99, math.min);
    final hi = days.map((d) => d.tempMax ?? -99).fold<double>(-99, math.max);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Column(
        children: [
          SectionTitle(
            '${days.length} günlük tahmin',
            icon: Icons.calendar_month_rounded,
            trailing: TextButton(onPressed: () => ShellNav.of(context).open(Dest.daily), child: const Text('Ayrıntı')),
          ),
          for (var i = 0; i < days.length && i < (AppPlatform.isDesktop ? 15 : 7); i++) _DayRow(d: days[i], index: i, lo: lo, hi: hi),
          if (!AppPlatform.isDesktop && days.length > 7)
            TextButton(onPressed: () => ShellNav.of(context).open(Dest.daily), child: Text('Tüm ${days.length} günü göster')),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('7. günden sonrası düşük güvenilirliklidir; genel eğilim olarak değerlendirin.', style: Sky.tiny),
          ),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.d, required this.index, required this.lo, required this.hi});
  final DailyPoint d;
  final int index;
  final double lo, hi;

  @override
  Widget build(BuildContext context) {
    final r = ReliabilityX.forDay(index);
    final span = math.max(1.0, hi - lo);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(index == 0 ? 'Bugün' : Fmt.dayShort(d.date), style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(Fmt.dayMonth(d.date), style: Sky.tiny),
              ],
            ),
          ),
          WeatherIcon(code: d.weatherCode, size: 30),
          SizedBox(
            width: 46,
            child: Text(
              (d.precipitationProbabilityMax ?? 0) >= 10 ? Fmt.pct(d.precipitationProbabilityMax) : '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Sky.accent, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: 36, child: Text(Fmt.temp(d.tempMin), textAlign: TextAlign.end, style: const TextStyle(color: Sky.textDim))),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(builder: (_, b) {
              final s = ((d.tempMin ?? lo) - lo) / span * b.maxWidth;
              final e = ((d.tempMax ?? hi) - lo) / span * b.maxWidth;
              return Stack(children: [
                Container(height: 5, decoration: BoxDecoration(color: Sky.surfaceStrong, borderRadius: BorderRadius.circular(4))),
                Positioned(
                  left: s,
                  width: math.max(6, e - s),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFF5CB8FF), Color(0xFFFFB861)]),
                    ),
                  ),
                ),
              ]);
            }),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 36, child: Text(Fmt.temp(d.tempMax), style: const TextStyle(fontWeight: FontWeight.w600))),
          Tooltip(message: r.label, child: Container(width: 7, height: 7, decoration: BoxDecoration(color: r.color, shape: BoxShape.circle))),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            '${Fmt.coord(f.latitude, f.longitude)}${f.elevation != null ? ' · ${f.elevation!.round()} m' : ''} · ${f.clock.timezone} (${f.clock.offsetLabel})',
            style: Sky.tiny,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const SourceNote('Hava durumu: Open-Meteo.com (CC BY 4.0) · Hava kalitesi: CAMS / Open-Meteo', url: 'https://open-meteo.com'),
        ],
      );
}
