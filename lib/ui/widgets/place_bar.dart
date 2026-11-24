import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../screens/places_screen.dart';

/// Başlıktaki konum adı; dokununca konum değiştirme sayfası açılır.
class PlaceTitle extends StatelessWidget {
  const PlaceTitle({super.key, this.prefix});

  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.place;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showPlacePicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefix != null) ...[
              Text(prefix!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('·', style: TextStyle(color: Sky.textFaint))),
            ],
            if (p?.isGps ?? false) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.near_me_rounded, size: 17, color: Sky.accent)),
            Flexible(
              child: Text(
                p?.name ?? 'Konum seçin',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: prefix == null ? 22 : 17, fontWeight: FontWeight.w600, color: prefix == null ? Sky.text : Sky.textDim),
              ),
            ),
            const Icon(Icons.expand_more_rounded, color: Sky.textDim),
          ],
        ),
      ),
    );
  }
}

/// Yenile + favori düğmeleri.
class PlaceActions extends StatelessWidget {
  const PlaceActions({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final p = c.place;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p != null)
          IconButton(
            tooltip: c.isFavorite(p) ? 'Favorilerden çıkar' : 'Favorilere ekle',
            onPressed: () => c.toggleFavorite(p),
            icon: Icon(c.isFavorite(p) ? Icons.star_rounded : Icons.star_outline_rounded, color: c.isFavorite(p) ? Sky.warm : null),
          ),
        IconButton(
          tooltip: 'Yenile',
          onPressed: c.forecast.isLoading || p == null ? null : () => c.refresh(force: true),
          icon: c.forecast.isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

Future<void> showPlacePicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Sky.bg2,
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => const FractionallySizedBox(heightFactor: 0.86, child: PlaceSearchPanel(closeOnSelect: true)),
    );
