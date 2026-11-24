import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../domain/aqi.dart';
import '../widgets/common.dart';

/// Yalnızca hava kalitesi indeksi (AQI). PM2.5/PM10/polen gösterilmez.
class AirScreen extends StatelessWidget {
  const AirScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final scale = c.settings.aqiScale;
    final a = c.air;
    if (a.hasError) return FailureView(failure: a.failure!, feature: 'Hava kalitesi (AQI)', onRetry: () => c.refresh(force: true));
    final aq = a.data;
    if (aq == null) return const LoadingView(label: 'Hava kalitesi alınıyor…');
    final v = scale == AqiScale.european ? aq.europeanAqi : aq.usAqi;
    final steps = scale == AqiScale.european ? [10.0, 30, 50, 70, 90, 110] : [25.0, 75, 125, 175, 250, 350];
    final stale = DateTime.now().difference(aq.fetchedAt) > const Duration(hours: 2);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        GlassCard(
          child: v == null
              ? const Text('Bu konum için AQI verisi yok.', style: Sky.small)
              : Column(
                  children: [
                    Text(Aqi.scaleName(scale), style: Sky.small),
                    const SizedBox(height: 8),
                    Text(Fmt.num0(v.round()), style: TextStyle(fontSize: 72, fontWeight: FontWeight.w300, color: Aqi.level(v, scale).color)),
                    Text(Aqi.level(v, scale).label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(Aqi.level(v, scale).advice, style: Sky.small, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Pill(stale ? 'Eski veri · ${Fmt.ago(aq.fetchedAt)}' : 'Model saati ${Fmt.hm(aq.time)} · ${Fmt.ago(aq.fetchedAt)} alındı',
                        color: stale ? Sky.warm : Sky.textDim),
                  ],
                ),
        ),
        const SizedBox(height: Sky.gap),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle('Ölçek', icon: Icons.legend_toggle_rounded),
              for (final s in steps)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    Container(width: 14, height: 14, decoration: BoxDecoration(color: Aqi.level(s, scale).color, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(Aqi.level(s, scale).label)),
                  ]),
                ),
              const SizedBox(height: 6),
              const Text('Ölçeği Ayarlar’dan değiştirebilirsiniz (Avrupa EAQI / ABD AQI).', style: Sky.tiny),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SourceNote('Kaynak: Copernicus Atmosfer İzleme Servisi (CAMS) · Open-Meteo Air Quality API', url: 'https://open-meteo.com/en/docs/air-quality-api'),
      ],
    );
  }
}
