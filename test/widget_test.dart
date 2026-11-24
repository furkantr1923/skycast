import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:skycast/app/app.dart';
import 'package:skycast/app/platform.dart';
import 'package:skycast/data/weather_repository.dart';
import 'package:skycast/domain/place.dart';
import 'package:skycast/state/app_controller.dart';

import 'controller_test.dart' show FakeForecast, FailingAir, NoAlarm;

void main() {
  setUpAll(() => initializeDateFormatting('tr_TR'));

  for (final desktop in [false, true]) {
    testWidgets('Panel gerçek veriyle açılır (${desktop ? 'Windows' : 'Android'} düzeni)', (tester) async {
      AppPlatform.debugDesktopOverride = desktop;
      tester.view.physicalSize = desktop ? const Size(1360, 860) : const Size(1080, 2340);
      tester.view.devicePixelRatio = desktop ? 1.0 : 2.75;
      addTearDown(tester.view.reset);
      final c = AppController(
        repo: WeatherRepository(forecastProvider: FakeForecast('storm'), airProvider: const FailingAir(), alarmProvider: const NoAlarm()),
        store: null,
      );
      await tester.pumpWidget(SkycastApp(controller: c));
      await tester.runAsync(() => c.select(const Place(name: 'İstanbul', latitude: 41, longitude: 29, countryCode: 'TR')));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('İstanbul'), findsWidgets);
      expect(find.text('12°'), findsWidgets);
      expect(find.text('Kapalı'), findsWidgets);
      expect(find.textContaining('Kuvvetli yağış'), findsWidgets);
      if (desktop) expect(find.textContaining('Hava kalitesi (AQI) şu an kullanılamıyor'), findsOneWidget);
      AppPlatform.debugDesktopOverride = null;
    });
  }
}
