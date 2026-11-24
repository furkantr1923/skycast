import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../app/theme.dart';
import '../../core/failure.dart';
import '../../domain/place.dart';
import '../../state/app_controller.dart';
import '../widgets/common.dart';

/// Konumlar: GPS, favoriler (sıralanabilir, sınırsız) ve küresel şehir araması.
class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(embedded ? 0 : 12, embedded ? 0 : 12, embedded ? 0 : 12, 0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const PlaceSearchPanel(closeOnSelect: false, showHeader: true),
          ),
        ),
      );
}

class PlaceSearchPanel extends StatefulWidget {
  const PlaceSearchPanel({super.key, required this.closeOnSelect, this.showHeader = false});

  final bool closeOnSelect;
  final bool showHeader;

  @override
  State<PlaceSearchPanel> createState() => _PlaceSearchPanelState();
}

class _PlaceSearchPanelState extends State<PlaceSearchPanel> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Place> _results = const [];
  AppFailure? _error;
  bool _searching = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    // Her tuşta istek atmamak için kısa bekleme.
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    final id = ++_seq;
    if (q.trim().length < 2) {
      setState(() {
        _results = const [];
        _error = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final r = await AppScope.read(context).repo.search(q);
      if (!mounted || id != _seq) return;
      setState(() {
        _results = r;
        _error = null;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || id != _seq) return;
      setState(() {
        _error = AppFailure.from(e);
        _searching = false;
      });
    }
  }

  void _pick(Place p) {
    AppScope.read(context).select(p);
    if (widget.closeOnSelect) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final query = _ctrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.closeOnSelect)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 42,
              height: 4,
              decoration: BoxDecoration(color: Sky.stroke, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        if (widget.showHeader)
          const Padding(padding: EdgeInsets.fromLTRB(8, 6, 8, 14), child: Text('Konumlar', style: Sky.title)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _ctrl,
            autofocus: widget.closeOnSelect && c.place == null,
            onChanged: _onChanged,
            onSubmitted: _search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Dünyanın her yerinden şehir arayın',
              suffixIcon: _ctrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _ctrl.clear();
                        _search('');
                      },
                    ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            children: [
              if (query.length >= 2) ..._buildResults() else ..._buildSaved(c),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildResults() {
    if (_searching) return [const Padding(padding: EdgeInsets.all(32), child: LoadingView(label: 'Aranıyor…'))];
    if (_error != null) return [FailureView(failure: _error!, onRetry: () => _search(_ctrl.text))];
    if (_results.isEmpty) {
      return [const Padding(padding: EdgeInsets.all(32), child: Text('Sonuç bulunamadı.', textAlign: TextAlign.center, style: Sky.small))];
    }
    final c = AppScope.read(context);
    return [
      for (final p in _results)
        ListTile(
          leading: const Icon(Icons.location_city_rounded),
          title: Text(p.name),
          subtitle: Text(p.subtitle, style: Sky.small),
          trailing: IconButton(
            tooltip: c.isFavorite(p) ? 'Favorilerden çıkar' : 'Favorilere ekle',
            icon: Icon(c.isFavorite(p) ? Icons.star_rounded : Icons.star_outline_rounded, color: c.isFavorite(p) ? Sky.warm : null),
            onPressed: () => setState(() => c.toggleFavorite(p)),
          ),
          onTap: () => _pick(p),
        ),
      const Padding(padding: EdgeInsets.only(top: 12), child: SourceNote('Şehir verisi: GeoNames · Open-Meteo Geocoding')),
    ];
  }

  List<Widget> _buildSaved(AppController c) {
    final gpsSubtitle = switch (c.gps) {
      GpsStatus.locating => 'Konum bulunuyor…',
      GpsStatus.ok => c.gpsPlace?.name ?? 'Konum bulundu',
      GpsStatus.denied => 'Konum izni verilmedi. Dokunup yeniden izin isteyin.',
      GpsStatus.disabled => 'Konum servisi kapalı.',
      GpsStatus.failed => 'Konum alınamadı. Yeniden deneyin.',
      GpsStatus.unknown => 'Cihaz konumunu kullan',
    };
    return [
      ListTile(
        leading: c.gps == GpsStatus.locating
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.my_location_rounded, color: Sky.accent),
        title: const Text('Mevcut konumum'),
        subtitle: Text(gpsSubtitle, style: Sky.small),
        onTap: c.gps == GpsStatus.locating
            ? null
            : () async {
                final ok = await c.locate();
                if (ok && widget.closeOnSelect && mounted) Navigator.of(context).maybePop();
              },
      ),
      const Divider(),
      SectionTitle('Favoriler (${c.favorites.length})', icon: Icons.star_rounded),
      if (c.favorites.isEmpty)
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Text('Henüz favori yok. Arama sonuçlarındaki ☆ simgesiyle ekleyebilirsiniz.', style: Sky.small),
        )
      else
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: c.reorderFavorites,
          children: [
            for (var i = 0; i < c.favorites.length; i++)
              ListTile(
                key: ValueKey(c.favorites[i].key),
                leading: ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_indicator_rounded)),
                title: Text(c.favorites[i].name),
                subtitle: c.favorites[i].subtitle.isEmpty ? null : Text(c.favorites[i].subtitle, style: Sky.small),
                selected: c.place == c.favorites[i],
                selectedColor: Sky.accent,
                trailing: IconButton(
                  tooltip: 'Favorilerden çıkar',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => c.toggleFavorite(c.favorites[i]),
                ),
                onTap: () => _pick(c.favorites[i]),
              ),
          ],
        ),
    ];
  }
}
