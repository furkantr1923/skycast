import 'dart:io';

import 'package:flutter/foundation.dart';

/// Platform farkları: Android gelişmiş sürüm, Windows sade masaüstü sürümü.
class AppPlatform {
  AppPlatform._();

  static bool? debugDesktopOverride;

  static bool get isDesktop =>
      debugDesktopOverride ?? (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS));

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
}
