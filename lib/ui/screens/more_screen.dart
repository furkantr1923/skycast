import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../shell.dart';
import '../widgets/common.dart';

/// Android: sekmelerde olmayan gelişmiş özellikler.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final n = c.activeAlerts.length;
    final items = <(IconData, String, String, Dest)>[
      (Icons.satellite_alt_rounded, 'Uydu', 'Bulut görüntüsü ve geçmiş kareler', Dest.satellite),
      (Icons.air_rounded, 'Rüzgâr', 'Pusula, hamle, Beaufort', Dest.wind),
      (Icons.show_chart_rounded, 'Grafikler', 'Saatlik ve günlük değişim', Dest.charts),
      (Icons.masks_outlined, 'Hava kalitesi', 'AQI indeksi', Dest.air),
      (Icons.warning_amber_rounded, 'Uyarılar', n == 0 ? 'Etkin uyarı yok' : '$n etkin uyarı', Dest.alerts),
      (Icons.place_rounded, 'Konumlarım', '${c.favorites.length} favori', Dest.places),
      (Icons.tune_rounded, 'Ayarlar', 'Görünüm ve tercihler', Dest.settings),
      (Icons.info_outline_rounded, 'Hakkında', 'Sürüm, kaynaklar, lisanslar', Dest.about),
    ];
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
        children: [
          Row(children: [
            Image.asset('assets/brand/logo.png', width: 40, height: 40),
            const SizedBox(width: 12),
            const Text('SKYCAST', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: 2)),
          ]),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              for (final it in items)
                GlassCard(
                  onTap: () => ShellNav.of(context).open(it.$4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(it.$1, color: it.$4 == Dest.alerts && n > 0 ? Sky.warm : Sky.accent, size: 28),
                      const Spacer(),
                      Text(it.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(it.$3, style: Sky.tiny, maxLines: 2),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
