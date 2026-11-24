import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/platform.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/weather.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';

enum ChartVar { temperature, precipitation, probability, wind, humidity, pressure, uv }

extension on ChartVar {
  String get label => switch (this) {
        ChartVar.temperature => 'Sıcaklık',
        ChartVar.precipitation => 'Yağış',
        ChartVar.probability => 'Yağış olasılığı',
        ChartVar.wind => 'Rüzgâr',
        ChartVar.humidity => 'Nem',
        ChartVar.pressure => 'Basınç',
        ChartVar.uv => 'UV',
      };
  String get unit => switch (this) {
        ChartVar.temperature => '°C',
        ChartVar.precipitation => 'mm',
        ChartVar.probability || ChartVar.humidity => '%',
        ChartVar.wind => 'km/sa',
        ChartVar.pressure => 'hPa',
        ChartVar.uv => '',
      };
}

class _Series {
  const _Series(this.name, this.values, this.color);
  final String name;
  final List<double?> values;
  final Color color;
}

/// Etkileşimli saatlik ve günlük grafikler (dokununca değer gösterir).
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  ChartVar _var = ChartVar.temperature;
  bool _daily = false;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final f = c.forecast.data;
    final body = Builder(builder: (context) {
      if (c.forecast.hasError) return FailureView(failure: c.forecast.failure!, onRetry: () => c.refresh(force: true));
      if (f == null) return c.place == null ? const Center(child: Text('Önce bir konum seçin.', style: Sky.small)) : const LoadingView();
      return ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, AppPlatform.isDesktop ? 24 : 40),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in ChartVar.values)
                ChoiceChip(label: Text(v.label), selected: _var == v, onSelected: (_) => setState(() => _var = v)),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Saatlik (48 sa)'), icon: Icon(Icons.schedule_rounded)),
              ButtonSegment(value: true, label: Text('Günlük (15 gün)'), icon: Icon(Icons.calendar_month_rounded)),
            ],
            selected: {_daily},
            onSelectionChanged: (s) => setState(() => _daily = s.first),
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(8, 16, 18, 10),
            child: SizedBox(height: AppPlatform.isDesktop ? 380 : 300, child: _chart(f)),
          ),
          const SizedBox(height: 10),
          _legend(f),
          const SizedBox(height: 14),
          const SourceNote('Veri: Open-Meteo.com (CC BY 4.0) · Günlük nem ve basınç, saatlik değerlerin ortalamasıdır.'),
        ],
      );
    });
    if (widget.embedded) return body;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
          child: Row(children: const [Expanded(child: Align(alignment: Alignment.centerLeft, child: PlaceTitle(prefix: 'Grafikler'))), PlaceActions()]),
        ),
        Expanded(child: body),
      ]),
    );
  }

  (List<DateTime>, List<_Series>, bool) _data(Forecast f) {
    if (_daily) {
      final d = f.daily.take(15).toList();
      final t = d.map((e) => e.date).toList();
      return switch (_var) {
        ChartVar.temperature => (t, [
            _Series('En yüksek', d.map((e) => e.tempMax).toList(), const Color(0xFFFFB861)),
            _Series('En düşük', d.map((e) => e.tempMin).toList(), const Color(0xFF5CB8FF)),
            _Series('Hissedilen (en yüksek)', d.map((e) => e.apparentMax).toList(), const Color(0x99FFFFFF)),
          ], false),
        ChartVar.precipitation => (t, [_Series('Toplam yağış', d.map((e) => e.precipitationSum).toList(), Sky.accent)], true),
        ChartVar.probability => (t, [_Series('En yüksek olasılık', d.map((e) => e.precipitationProbabilityMax).toList(), Sky.accent2)], false),
        ChartVar.wind => (t, [
            _Series('Rüzgâr (en yüksek)', d.map((e) => e.windSpeedMax).toList(), const Color(0xFF6EE7B7)),
            _Series('Hamle (en yüksek)', d.map((e) => e.windGustsMax).toList(), const Color(0xFFFCA5A5)),
          ], false),
        ChartVar.humidity => (t, [_Series('Ortalama nem', d.map((e) => e.humidityMean).toList(), const Color(0xFF7DD3FC))], false),
        ChartVar.pressure => (t, [_Series('Ortalama basınç', d.map((e) => e.pressureMean).toList(), const Color(0xFFC4B5FD))], false),
        ChartVar.uv => (t, [_Series('UV (en yüksek)', d.map((e) => e.uvIndexMax).toList(), const Color(0xFFFDE047))], false),
      };
    }
    final h = f.upcomingHours(48);
    final t = h.map((e) => e.time).toList();
    return switch (_var) {
      ChartVar.temperature => (t, [
          _Series('Sıcaklık', h.map((e) => e.temperature).toList(), const Color(0xFFFFB861)),
          _Series('Hissedilen', h.map((e) => e.apparentTemperature).toList(), const Color(0xFF5CB8FF)),
        ], false),
      ChartVar.precipitation => (t, [_Series('Yağış', h.map((e) => e.precipitation).toList(), Sky.accent)], true),
      ChartVar.probability => (t, [_Series('Yağış olasılığı', h.map((e) => e.precipitationProbability).toList(), Sky.accent2)], false),
      ChartVar.wind => (t, [
          _Series('Rüzgâr', h.map((e) => e.windSpeed).toList(), const Color(0xFF6EE7B7)),
          _Series('Hamle', h.map((e) => e.windGusts).toList(), const Color(0xFFFCA5A5)),
        ], false),
      ChartVar.humidity => (t, [_Series('Nem', h.map((e) => e.humidity).toList(), const Color(0xFF7DD3FC))], false),
      ChartVar.pressure => (t, [_Series('Basınç', h.map((e) => e.pressure).toList(), const Color(0xFFC4B5FD))], false),
      ChartVar.uv => (t, [_Series('UV indeksi', h.map((e) => e.uvIndex).toList(), const Color(0xFFFDE047))], false),
    };
  }

  Widget _legend(Forecast f) {
    final (_, series, _) = _data(f);
    return Wrap(spacing: 16, runSpacing: 6, children: [
      for (final s in series)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 4, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 6),
          Text('${s.name}${_var.unit.isEmpty ? '' : ' (${_var.unit})'}', style: Sky.small),
        ]),
    ]);
  }

  String _xLabel(DateTime t) => _daily ? Fmt.dayShort(t) : Fmt.hm(t);

  Widget _chart(Forecast f) {
    final (times, series, bars) = _data(f);
    final all = series.expand((s) => s.values).whereType<double>().toList();
    if (times.isEmpty || all.isEmpty) {
      return const Center(child: Text('Bu değişken için veri yok.', style: Sky.small));
    }
    var minY = all.reduce(math.min);
    var maxY = all.reduce(math.max);
    if (_var == ChartVar.probability || _var == ChartVar.humidity) {
      minY = 0;
      maxY = 100;
    } else if (bars || _var == ChartVar.uv || _var == ChartVar.wind) {
      minY = 0;
      maxY = math.max(maxY * 1.15, bars ? 1 : 5);
    } else {
      final pad = math.max(1.0, (maxY - minY) * 0.12);
      minY -= pad;
      maxY += pad;
    }
    final step = _daily ? 2 : 6;

    Widget bottom(double v, TitleMeta meta) {
      final i = v.round();
      if (i < 0 || i >= times.length || i % step != 0 || (v - i).abs() > 0.01) return const SizedBox.shrink();
      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(_xLabel(times[i]), style: Sky.tiny));
    }

    Widget left(double v, TitleMeta meta) {
      if (v == meta.max || v == meta.min) return const SizedBox.shrink();
      return Text(Fmt.num0(v.round()), style: Sky.tiny);
    }

    final titles = FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 26, interval: 1, getTitlesWidget: bottom)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, getTitlesWidget: left)),
    );
    final grid = FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) => const FlLine(color: Sky.stroke, strokeWidth: 1),
    );

    if (bars) {
      final s = series.first;
      return BarChart(BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: grid,
        borderData: FlBorderData(show: false),
        titlesData: titles,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xEE162033),
            getTooltipItem: (group, _, rod, _) => BarTooltipItem(
              '${_daily ? Fmt.dayMonth(times[group.x]) : Fmt.dateTime(times[group.x])}\n${Fmt.mm(rod.toY)}',
              const TextStyle(color: Sky.text, fontSize: 12),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < times.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: s.values[i] ?? 0,
                width: _daily ? 14 : 5,
                color: s.color,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
            ]),
        ],
      ));
    }

    return LineChart(LineChartData(
      minX: 0,
      maxX: (times.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      gridData: grid,
      borderData: FlBorderData(show: false),
      titlesData: titles,
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => const Color(0xEE162033),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (spots) => [
            for (var k = 0; k < spots.length; k++)
              LineTooltipItem(
                '${k == 0 ? '${_daily ? Fmt.dayMonth(times[spots[k].x.round()]) : Fmt.dateTime(times[spots[k].x.round()])}\n' : ''}'
                '${series[spots[k].barIndex].name}: ${Fmt.num1(spots[k].y)} ${_var.unit}',
                TextStyle(color: series[spots[k].barIndex].color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
          ],
        ),
      ),
      lineBarsData: [
        for (var si = 0; si < series.length; si++)
          LineChartBarData(
            spots: [
              for (var i = 0; i < times.length; i++)
                if (series[si].values[i] != null) FlSpot(i.toDouble(), series[si].values[i]!) else FlSpot.nullSpot,
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: series[si].color,
            barWidth: si == 0 ? 3 : 2,
            dotData: FlDotData(show: _daily),
            dashArray: si == 2 ? [5, 4] : null,
            belowBarData: BarAreaData(
              show: si == 0,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [series[si].color.withValues(alpha: 0.28), series[si].color.withValues(alpha: 0.0)],
              ),
            ),
          ),
      ],
    ));
  }
}
