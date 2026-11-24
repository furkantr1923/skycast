import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/common.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(16), children: const [AboutContent()]);
}

/// Hakkında: sürüm, geliştirici atfı, veri kaynakları ve lisanslar.
class AboutContent extends StatelessWidget {
  const AboutContent({super.key});

  static const version = '1.0.0';

  static const sources = <(String, String, String)>[
    ('Hava durumu, 15 gün, harita ızgaraları', 'Open-Meteo.com · CC BY 4.0', 'https://open-meteo.com'),
    ('Hava kalitesi (AQI)', 'CAMS / Open-Meteo Air Quality', 'https://open-meteo.com/en/docs/air-quality-api'),
    ('Yağış radarı', 'RainViewer (kişisel/eğitim kullanımı)', 'https://www.rainviewer.com'),
    ('Uydu (Meteosat / MTG)', '© EUMETSAT · EUMETView', 'https://view.eumetsat.int'),
    ('Uydu (günlük gerçek renk)', 'NASA EOSDIS GIBS', 'https://earthdata.nasa.gov/gibs'),
    ('Resmî uyarılar (Avrupa)', 'MeteoAlarm / EUMETNET', 'https://meteoalarm.org'),
    ('Altlık harita', '© OpenStreetMap katkıcıları · ODbL', 'https://www.openstreetmap.org/copyright'),
    ('Şehir arama', 'GeoNames · Open-Meteo Geocoding', 'https://open-meteo.com/en/docs/geocoding-api'),
    ('Konum adı', 'OpenStreetMap Nominatim · ODbL', 'https://nominatim.org'),
  ];

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Image.asset('assets/brand/logo.png', width: 84, height: 84),
              const SizedBox(height: 12),
              const Text('SKYCAST', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 4)),
              const SizedBox(height: 4),
              const Text('Sürüm $version', style: Sky.small),
              const SizedBox(height: 14),
              const Text('SKYCAST — Furkan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Sky.accent)),
              const SizedBox(height: 10),
              const Text(
                'Hesap yok, reklam yok, bildirim yok. Yalnızca ücretsiz ve açık erişimli kaynaklar kullanılır; '
                'veri olmayan yerde değer uydurulmaz.',
                style: Sky.small,
                textAlign: TextAlign.center,
              ),
            ]),
          ),
          const SizedBox(height: Sky.gap),
          const SectionTitle('Veri kaynakları ve atıflar', icon: Icons.source_outlined),
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [
              for (final s in sources)
                ListTile(
                  dense: true,
                  title: Text(s.$1),
                  subtitle: SourceNote(s.$2, url: s.$3, align: TextAlign.start),
                ),
            ]),
          ),
          const SizedBox(height: Sky.gap),
          Center(
            child: TextButton.icon(
              onPressed: () => showLicensePage(context: context, applicationName: 'SKYCAST', applicationVersion: version),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Açık kaynak lisansları'),
            ),
          ),
        ],
      );
}
