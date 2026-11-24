import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../domain/aqi.dart';
import '../widgets/common.dart';
import 'about_screen.dart';

/// Ayarlar. Birimler sabittir (°C, km/sa, mm, hPa) ve değiştirilemez.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false, this.showAbout = false});
  final bool embedded;
  final bool showAbout;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final s = c.settings;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (!embedded) const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 16), child: Text('Ayarlar', style: Sky.title)),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            SwitchListTile(
              value: s.useGps,
              onChanged: (v) => c.updateSettings(s.copyWith(useGps: v)),
              title: const Text('Açılışta konumumu kullan'),
              subtitle: const Text('Konum yalnızca uygulama açıkken alınır', style: Sky.small),
              secondary: const Icon(Icons.my_location_rounded),
            ),
            SwitchListTile(
              value: s.animatedBackground,
              onChanged: (v) => c.updateSettings(s.copyWith(animatedBackground: v)),
              title: const Text('Hareketli atmosfer arka planı'),
              subtitle: const Text('Kapatmak pil ve işlemci kullanımını azaltır', style: Sky.small),
              secondary: const Icon(Icons.animation_rounded),
            ),
            ListTile(
              leading: const Icon(Icons.masks_outlined),
              title: const Text('Hava kalitesi ölçeği'),
              subtitle: Text(Aqi.scaleName(s.aqiScale), style: Sky.small),
              trailing: SegmentedButton<AqiScale>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: AqiScale.european, label: Text('AB')), ButtonSegment(value: AqiScale.us, label: Text('ABD'))],
                selected: {s.aqiScale},
                onSelectionChanged: (v) => c.updateSettings(s.copyWith(aqiScale: v.first)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.slow_motion_video_rounded),
              title: const Text('Radar/uydu animasyon hızı'),
              subtitle: Slider(
                value: s.radarFrameMs.toDouble(),
                min: 300,
                max: 1500,
                divisions: 12,
                label: '${s.radarFrameMs} ms/kare',
                onChanged: (v) => c.updateSettings(s.copyWith(radarFrameMs: v.round())),
              ),
            ),
          ]),
        ),
        const SizedBox(height: Sky.gap),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(children: [
            const ListTile(
              leading: Icon(Icons.straighten_rounded),
              title: Text('Birimler'),
              subtitle: Text('Sıcaklık °C · Rüzgâr km/sa · Yağış mm · Basınç hPa (sabit)', style: Sky.small),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Uyarı geçmişini temizle'),
              subtitle: Text('${c.history.length} kayıt', style: Sky.small),
              onTap: c.history.isEmpty ? null : c.clearHistory,
            ),
            ListTile(
              leading: const Icon(Icons.cached_rounded),
              title: const Text('Önbelleği temizle ve yenile'),
              subtitle: const Text('Tüm veriler kaynaktan yeniden alınır', style: Sky.small),
              onTap: () {
                c.repo.clearCache();
                c.refresh(force: true);
              },
            ),
          ]),
        ),
        if (showAbout) ...[
          const SizedBox(height: 24),
          const AboutContent(),
        ],
      ],
    );
    return SafeArea(bottom: false, child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: list)));
  }
}
