import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../core/format.dart';
import '../../data/providers/meteoalarm.dart';
import '../../domain/alert.dart';
import '../widgets/common.dart';
import '../widgets/place_bar.dart';

/// Uygulama içi uyarılar ve uyarı geçmişi. Bildirim YOKTUR; uyarılar yalnızca burada görünür.
class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final tabs = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(tabs: [Tab(text: 'Etkin (${c.activeAlerts.length})'), Tab(text: 'Geçmiş (${c.history.length})')]),
          const Expanded(child: TabBarView(children: [_Active(), _History()])),
        ],
      ),
    );
    if (embedded) return tabs;
    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
          child: Row(children: const [Expanded(child: Align(alignment: Alignment.centerLeft, child: PlaceTitle(prefix: 'Uyarılar'))), PlaceActions()]),
        ),
        Expanded(child: tabs),
      ]),
    );
  }
}

class _Active extends StatelessWidget {
  const _Active();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.place;
    if (p == null) return const Center(child: Text('Önce bir konum seçin.', style: Sky.small));
    final official = c.official;
    Widget officialStatus;
    if (official.isLoading) {
      officialStatus = const Text('Resmî uyarılar kontrol ediliyor…', style: Sky.small);
    } else if (official.hasError) {
      officialStatus = Text(
        official.failure!.kind == FailureKind.notSupported
            ? 'Bu ülke için ücretsiz ve açık bir resmî uyarı akışı bulunamadı (MeteoAlarm ${p.countryCode == 'TR' ? 'Türkiye’yi kapsamıyor' : 'bu ülkeyi kapsamıyor'}). '
                'Resmî uyarılar için ulusal meteoroloji servisini (Türkiye’de MGM) takip edin.'
            : 'Resmî uyarı kaynağına ulaşılamadı: ${official.failure!.title}.',
        style: Sky.small,
      );
    } else {
      final n = official.data?.length ?? 0;
      officialStatus = Text(n == 0 ? 'MeteoAlarm: bu konum için etkin resmî uyarı yok.' : 'MeteoAlarm: $n resmî uyarı.', style: Sky.small);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.verified_rounded, size: 18, color: Sky.good),
              SizedBox(width: 8),
              Text('Resmî uyarılar', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            officialStatus,
            const SizedBox(height: 12),
            const Row(children: [
              Icon(Icons.calculate_outlined, size: 18, color: Sky.accent),
              SizedBox(width: 8),
              Text('Uygulama göstergeleri', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 6),
            const Text(
              'Open-Meteo tahminindeki değerler belirli eşikleri aştığında SKYCAST tarafından hesaplanır. '
              'Resmî uyarı DEĞİLDİR; yalnızca önümüzdeki 3 gün için bilgi amaçlıdır.',
              style: Sky.small,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (c.forecast.hasError)
          FailureView(failure: c.forecast.failure!, compact: true, feature: 'Uygulama göstergeleri', onRetry: () => c.refresh(force: true))
        else if (c.activeAlerts.isEmpty && !c.forecast.isLoading)
          const Padding(
            padding: EdgeInsets.all(28),
            child: Column(children: [
              Icon(Icons.check_circle_outline_rounded, size: 40, color: Sky.good),
              SizedBox(height: 10),
              Text('Önümüzdeki 3 gün için önemli bir hava olayı görünmüyor.', textAlign: TextAlign.center),
            ]),
          ),
        for (final a in c.activeAlerts) AlertCard(alert: a),
        if (MeteoAlarmProvider.covers(p.countryCode))
          const SourceNote('Resmî uyarılar: MeteoAlarm / EUMETNET', url: 'https://meteoalarm.org'),
      ],
    );
  }
}

class _History extends StatelessWidget {
  const _History();

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    if (c.history.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(28), child: Text('Henüz uyarı geçmişi yok.', style: Sky.small)));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
      children: [
        Row(children: [
          const Expanded(child: Text('Uygulamada görülen uyarılar bu cihazda saklanır.', style: Sky.tiny)),
          TextButton.icon(onPressed: c.clearHistory, icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Temizle')),
        ]),
        for (final a in c.history) AlertCard(alert: a, showSeen: true),
      ],
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, this.showSeen = false});
  final WeatherAlert alert;
  final bool showSeen;

  IconData get _icon => switch (alert.type) {
        AlertType.heavyRain => Icons.water_drop_rounded,
        AlertType.heavySnow => Icons.ac_unit_rounded,
        AlertType.storm => Icons.storm_rounded,
        AlertType.heat => Icons.local_fire_department_rounded,
        AlertType.extremeCold => Icons.severe_cold_rounded,
        AlertType.frost => Icons.ac_unit_rounded,
        AlertType.ice => Icons.snowing,
        AlertType.flood => Icons.flood_rounded,
        AlertType.hail => Icons.grain_rounded,
        AlertType.lightning => Icons.thunderstorm_rounded,
        AlertType.strongWind => Icons.air_rounded,
        AlertType.other => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final col = alert.severity.color;
    final official = alert.origin == AlertOrigin.official;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(Sky.radiusSm),
        border: Border(left: BorderSide(color: col, width: 4)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(_icon, color: col, size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(alert.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            Pill(alert.severity.label, color: col),
          ]),
          const SizedBox(height: 8),
          Text(alert.description, style: Sky.small),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            Pill(official ? 'RESMÎ UYARI' : 'UYGULAMA GÖSTERGESİ · resmî değil',
                color: official ? Sky.good : Sky.accent, icon: official ? Icons.verified_rounded : Icons.calculate_outlined),
            Pill(alert.placeName, color: Sky.textDim, icon: Icons.place_outlined),
          ]),
          const SizedBox(height: 6),
          Text(
            [
              if (alert.source != null) 'Kaynak: ${alert.source}',
              if (alert.end != null) 'Geçerlilik: ${Fmt.dateTime(alert.start)} – ${Fmt.dateTime(alert.end!)}',
              if (showSeen && alert.firstSeen != null) 'İlk görülme: ${Fmt.dateTime(alert.firstSeen!)}',
            ].join(' · '),
            style: Sky.tiny,
          ),
        ],
      ),
    );
  }
}
