import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'capture/capture_runner.dart';
import 'data/storage/local_store.dart';
import 'data/weather_repository.dart';
import 'state/app_controller.dart';
import 'ui/shell.dart';

/// SKYCAST giriş noktası.
///
/// `--capture=<klasör>` (Windows) ya da `--dart-define=SKYCAST_CAPTURE=true`
/// (Android) ile başlatılırsa uygulama kendi kendini sınar, ekran
/// görüntülerini alır ve rapor yazar. Normal kullanımda bu kod çalışmaz.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Harita döşemeleri için çözülmüş görüntü önbelleğini sınırla (düşük bellek).
  PaintingBinding.instance.imageCache
    ..maximumSizeBytes = 96 << 20
    ..maximumSize = 400;
  await initializeDateFormatting('tr_TR');

  final capture = CaptureConfig.fromArgs(args);
  final store = capture == null ? await LocalStore.open() : null;
  final controller = AppController(repo: WeatherRepository(), store: store);
  final shellKey = GlobalKey<AppShellState>();
  final boundaryKey = GlobalKey();

  runApp(SkycastApp(controller: controller, shellKey: shellKey, boundaryKey: boundaryKey));

  if (capture != null) {
    await CaptureRunner(config: capture, controller: controller, shellKey: shellKey, boundaryKey: boundaryKey).run();
  } else {
    await controller.init();
  }
}
