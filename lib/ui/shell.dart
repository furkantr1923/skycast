import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../app/platform.dart';
import '../app/theme.dart';
import '../domain/alert.dart';
import 'screens/about_screen.dart';
import 'screens/air_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/charts_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/more_screen.dart';
import 'screens/places_screen.dart';
import 'screens/radar_screen.dart';
import 'screens/satellite_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/wind_screen.dart';
import 'maps/weather_map_screen.dart';
import 'widgets/place_bar.dart';

/// Uygulamadaki tüm hedef ekranlar.
enum Dest { today, hourly, daily, maps, radar, satellite, wind, charts, air, alerts, places, settings, about }

/// Ekranların başka bir ekrana geçmesini sağlar.
class ShellNav extends InheritedWidget {
  const ShellNav({super.key, required this.open, required super.child});

  final void Function(Dest dest) open;

  static ShellNav of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellNav>()!;

  @override
  bool updateShouldNotify(ShellNav oldWidget) => false;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _index = 0;
  int _forecastTab = 0;
  int _mapTab = 0;

  /// Tembel yükleme: bir sekme ilk kez açılana kadar oluşturulmaz
  /// (harita, radar ve uydu gereksiz yere veri indirmesin).
  final Set<int> _visited = {0};

  Widget _lazy(List<Widget> pages) {
    _visited.add(_index);
    return IndexedStack(
      index: _index,
      children: [for (var i = 0; i < pages.length; i++) _visited.contains(i) ? pages[i] : const SizedBox.shrink()],
    );
  }

  bool get _desktop => AppPlatform.isDesktop;

  /// Ekranı açar. Android'de sekmede olmayan ekranlar tam ekran açılır.
  void open(Dest d) {
    if (_desktop) {
      final (i, sub) = switch (d) {
        Dest.today || Dest.wind || Dest.air => (0, -1),
        Dest.hourly => (1, 0),
        Dest.daily => (1, 1),
        Dest.charts => (2, -1),
        Dest.maps => (3, 0),
        Dest.radar => (3, 1),
        Dest.satellite => (3, 2),
        Dest.alerts => (4, -1),
        Dest.places => (5, -1),
        Dest.settings || Dest.about => (6, -1),
      };
      setState(() {
        _index = i;
        if (i == 1 && sub >= 0) _forecastTab = sub;
        if (i == 3 && sub >= 0) _mapTab = sub;
      });
      return;
    }
    final tab = switch (d) {
      Dest.today => 0,
      Dest.hourly || Dest.daily => 1,
      Dest.maps => 2,
      Dest.radar => 3,
      _ => -1,
    };
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (tab >= 0) {
      setState(() {
        _index = tab;
        if (tab == 1) _forecastTab = d == Dest.daily ? 1 : 0;
      });
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _FullScreen(dest: d)));
  }

  /// Sekmeye doğrudan geçer (öz-sınama modunda kullanılır).
  void openTab(int i) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final alertCount = c.activeAlerts.where((a) => a.severity.index >= AlertSeverity.yellow.index).length;
    return ShellNav(
      open: open,
      child: _desktop ? _buildDesktop(alertCount) : _buildMobile(alertCount),
    );
  }

  Widget _badge(Widget icon, int n) => n == 0 ? icon : Badge(label: Text('$n'), child: icon);

  Widget _buildMobile(int alerts) {
    final pages = <Widget>[
      const DashboardScreen(),
      ForecastScreen(key: ValueKey('f$_forecastTab'), initialTab: _forecastTab),
      const WeatherMapScreen(),
      const RadarScreen(),
      const MoreScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: _lazy(pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny_rounded), label: 'Bugün'),
          const NavigationDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week_rounded), label: 'Tahmin'),
          const NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: 'Harita'),
          const NavigationDestination(icon: Icon(Icons.radar_outlined), selectedIcon: Icon(Icons.radar_rounded), label: 'Radar'),
          NavigationDestination(
            icon: _badge(const Icon(Icons.grid_view_outlined), alerts),
            selectedIcon: _badge(const Icon(Icons.grid_view_rounded), alerts),
            label: 'Daha fazla',
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(int alerts) {
    final pages = <Widget>[
      const DashboardScreen(),
      ForecastScreen(key: ValueKey('f$_forecastTab'), initialTab: _forecastTab),
      const ChartsScreen(),
      DesktopMapsScreen(key: ValueKey('m$_mapTab'), initialTab: _mapTab),
      const AlertsScreen(),
      const PlacesScreen(),
      const SettingsScreen(showAbout: true),
    ];
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            minWidth: 88,
            leading: Padding(
              padding: const EdgeInsets.only(top: 18, bottom: 22),
              child: Column(
                children: [
                  Image.asset('assets/brand/logo.png', width: 42, height: 42),
                  const SizedBox(height: 6),
                  const Text('SKYCAST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
                ],
              ),
            ),
            destinations: [
              const NavigationRailDestination(icon: Icon(Icons.wb_sunny_outlined), selectedIcon: Icon(Icons.wb_sunny_rounded), label: Text('Panel')),
              const NavigationRailDestination(icon: Icon(Icons.calendar_view_week_outlined), selectedIcon: Icon(Icons.calendar_view_week_rounded), label: Text('Tahmin')),
              const NavigationRailDestination(icon: Icon(Icons.show_chart_rounded), label: Text('Grafikler')),
              const NavigationRailDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map_rounded), label: Text('Haritalar')),
              NavigationRailDestination(
                icon: _badge(const Icon(Icons.warning_amber_rounded), alerts),
                label: const Text('Uyarılar'),
              ),
              const NavigationRailDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place_rounded), label: Text('Konumlar')),
              const NavigationRailDestination(icon: Icon(Icons.tune_rounded), label: Text('Ayarlar')),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _lazy(pages)),
        ],
      ),
    );
  }
}

/// Android'de "Daha fazla" menüsünden açılan ekranlar.
class _FullScreen extends StatelessWidget {
  const _FullScreen({required this.dest});
  final Dest dest;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (dest) {
      Dest.satellite => ('Uydu', const SatelliteScreen()),
      Dest.wind => ('Rüzgâr', const WindScreen()),
      Dest.charts => ('Grafikler', const ChartsScreen(embedded: true)),
      Dest.air => ('Hava kalitesi', const AirScreen()),
      Dest.alerts => ('Uyarılar', const AlertsScreen(embedded: true)),
      Dest.places => ('Konumlarım', const PlacesScreen(embedded: true)),
      Dest.settings => ('Ayarlar', const SettingsScreen(embedded: true)),
      Dest.about => ('SKYCAST hakkında', const AboutScreen()),
      _ => ('SKYCAST', const SizedBox()),
    };
    final showPlace = dest == Dest.wind || dest == Dest.charts || dest == Dest.air || dest == Dest.alerts;
    return Scaffold(
      backgroundColor: Sky.bg,
      appBar: AppBar(title: showPlace ? PlaceTitle(prefix: title) : Text(title)),
      body: SafeArea(top: false, child: body),
    );
  }
}

/// Windows: harita katmanları, radar ve uydu tek ekranda sekmelerle.
class DesktopMapsScreen extends StatelessWidget {
  const DesktopMapsScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        initialIndex: initialTab,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  Expanded(child: PlaceTitle(prefix: 'Haritalar')),
                  SizedBox(
                    width: 360,
                    child: TabBar(tabs: [Tab(text: 'Katmanlar'), Tab(text: 'Radar'), Tab(text: 'Uydu')]),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                physics: NeverScrollableScrollPhysics(),
                children: [WeatherMapScreen(embedded: true), RadarScreen(embedded: true), SatelliteScreen(embedded: true)],
              ),
            ),
          ],
        ),
      );
}
