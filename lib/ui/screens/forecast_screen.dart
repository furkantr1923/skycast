import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/platform.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/reliability.dart';
import '../../domain/weather.dart';
import '../../domain/weather_code.dart';
import '../../domain/wind.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';
import '../widgets/weather_icon.dart';

/// Saatlik ve 15 günlük tahmin.
class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
              child: Row(children: const [Expanded(child: Align(alignment: Alignment.centerLeft, child: PlaceTitle(prefix: 'Tahmin'))), PlaceActions()]),
            ),
            const TabBar(tabs: [Tab(text: 'Saatlik'), Tab(text: '15 Gün')]),
            Expanded(
              child: Builder(builder: (context) {
                if (c.place == null) return const Center(child: Text('Önce bir konum seçin.', style: Sky.small));
                if (c.forecast.hasError) return FailureView(failure: c.forecast.failure!, onRetry: () => c.refresh(force: true));
                final f = c.forecast.data;
                if (f == null) return const LoadingView();
                return TabBarView(children: [_HourlyList(f: f), _DailyList(f: f)]);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _HourlyList extends StatelessWidget {
  const _HourlyList({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final hours = f.upcomingHours(72);
    final items = <Widget>[];
    int? day;
    for (final h in hours) {
      if (h.time.day != day) {
        day = h.time.day;
        items.add(Padding(
          padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
          child: Text('${Fmt.dayLong(h.time)}, ${Fmt.dayMonth(h.time)}'.toUpperCase(), style: Sky.section),
        ));
      }
      items.add(_HourRow(h: h));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 0, 12, AppPlatform.isDesktop ? 24 : 110),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, left: 6),
          child: Text('72 saat · konum saati (${f.clock.offsetLabel}) · veri ${Fmt.ago(f.fetchedAt)} alındı', style: Sky.tiny),
        ),
        ...items,
        const SizedBox(height: 12),
        const SourceNote('Veri: Open-Meteo.com (CC BY 4.0)'),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.h});
  final HourlyPoint h;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 720;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Sky.surface, borderRadius: BorderRadius.circular(Sky.radiusSm)),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(Fmt.hm(h.time), style: const TextStyle(fontWeight: FontWeight.w600))),
          WeatherIcon(code: h.weatherCode, isDay: h.isDay, size: 32),
          const SizedBox(width: 10),
          SizedBox(
            width: wide ? 160 : 70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Fmt.temp(h.temperature), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                Text(wide ? 'Hissedilen ${Fmt.temp(h.apparentTemperature)} · ${WeatherCode.describe(h.weatherCode)}' : 'His. ${Fmt.temp(h.apparentTemperature)}',
                    style: Sky.tiny, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.water_drop_rounded, size: 13, color: Sky.accent),
                  const SizedBox(width: 3),
                  Text('${Fmt.pct(h.precipitationProbability)} · ${Fmt.mm(h.precipitation)}', style: Sky.small),
                ]),
                const SizedBox(height: 3),
                Text('Nem ${Fmt.pct(h.humidity)}${wide ? ' · ${Fmt.hpa(h.pressure)} · UV ${Fmt.num1(h.uvIndex)}' : ''}', style: Sky.tiny),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(children: [
                WindArrow(degrees: h.windDirection, size: 15),
                const SizedBox(width: 3),
                Text(Fmt.wind(h.windSpeed), style: Sky.small),
              ]),
              const SizedBox(height: 3),
              Text('Hamle ${Fmt.num0(h.windGusts?.round())} · ${Wind.direction(h.windDirection)}', style: Sky.tiny),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyList extends StatelessWidget {
  const _DailyList({required this.f});
  final Forecast f;

  @override
  Widget build(BuildContext context) {
    final days = f.daily.take(15).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(12, 10, 12, AppPlatform.isDesktop ? 24 : 110),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: Sky.textDim),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tahminin güvenilirliği gün ilerledikçe azalır: 1–3. gün yüksek, 4–7. gün orta, 8–15. gün düşük (eğilim). '
                'Kaynak ${days.length} gün veriyor; eksik günler doldurulmaz.',
                style: Sky.small,
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < days.length; i++) _DayCard(d: days[i], index: i),
        const SizedBox(height: 12),
        SourceNote('Veri: Open-Meteo.com (CC BY 4.0) · alındı ${Fmt.dateTime(f.fetchedAt)}'),
      ],
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.d, required this.index});
  final DailyPoint d;
  final int index;

  @override
  Widget build(BuildContext context) {
    final r = ReliabilityX.forDay(index);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(color: Sky.surface, borderRadius: BorderRadius.circular(Sky.radiusSm)),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            leading: WeatherIcon(code: d.weatherCode, size: 36),
            title: Row(children: [
              Text(index == 0 ? 'Bugün' : Fmt.dayLong(d.date), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(Fmt.dayMonth(d.date), style: Sky.small),
            ]),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(WeatherCode.describe(d.weatherCode), style: Sky.small),
                Pill(r.label, color: r.color),
              ]),
            ),
            trailing: Text('${Fmt.temp(d.tempMax)} / ${Fmt.temp(d.tempMin)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            children: [
              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _kv('Hissedilen', '${Fmt.temp(d.apparentMax)} / ${Fmt.temp(d.apparentMin)}'),
                  _kv('Yağış', Fmt.mm(d.precipitationSum)),
                  _kv('Yağış olasılığı', Fmt.pct(d.precipitationProbabilityMax)),
                  if ((d.snowfallSum ?? 0) > 0) _kv('Kar', Fmt.cm(d.snowfallSum)),
                  _kv('Rüzgâr', '${Fmt.wind(d.windSpeedMax)} ${Wind.direction(d.windDirectionDominant)}'),
                  _kv('Hamle', Fmt.wind(d.windGustsMax)),
                  _kv('Beaufort', '${Wind.beaufort(d.windSpeedMax)} · ${Wind.beaufortName(Wind.beaufort(d.windSpeedMax))}'),
                  _kv('UV (en yüksek)', Fmt.num1(d.uvIndexMax)),
                  _kv('Nem (ort.)', Fmt.pct(d.humidityMean)),
                  _kv('Basınç (ort.)', Fmt.hpa(d.pressureMean)),
                  if (d.sunrise != null) _kv('Gün doğumu', Fmt.hm(d.sunrise!)),
                  if (d.sunset != null) _kv('Gün batımı', Fmt.hm(d.sunset!)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: Sky.tiny),
          const SizedBox(height: 2),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
