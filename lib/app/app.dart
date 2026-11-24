import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../state/app_controller.dart';
import '../ui/shell.dart';
import 'app_scope.dart';
import 'theme.dart';

class SkycastApp extends StatelessWidget {
  const SkycastApp({super.key, required this.controller, this.shellKey, this.boundaryKey});

  final AppController controller;
  final GlobalKey<AppShellState>? shellKey;

  /// Ekran görüntüsü modunda tüm arayüzü yakalamak için.
  final GlobalKey? boundaryKey;

  @override
  Widget build(BuildContext context) => AppScope(
        controller: controller,
        child: MaterialApp(
          title: 'SKYCAST',
          debugShowCheckedModeBanner: false,
          theme: Sky.theme(),
          darkTheme: Sky.theme(),
          themeMode: ThemeMode.dark,
          locale: const Locale('tr', 'TR'),
          supportedLocales: const [Locale('tr', 'TR')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => RepaintBoundary(key: boundaryKey, child: child),
          home: _Splash(child: AppShell(key: shellKey)),
        ),
      );
}

/// Kısa açılış ekranı: marka + yükleme; ilk veri gelince panele geçer.
class _Splash extends StatefulWidget {
  const _Splash({required this.child});
  final Widget child;

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _done
            ? widget.child
            : const Scaffold(
                key: ValueKey('splash'),
                body: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: Alignment(0, -0.3), radius: 1.2, colors: [Color(0xFF12305A), Sky.bg]),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image(image: AssetImage('assets/brand/logo.png'), width: 112, height: 112),
                        SizedBox(height: 18),
                        Text('SKYCAST', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: 8)),
                        SizedBox(height: 6),
                        Text('Gökyüzünü gerçek veriyle izleyin', style: Sky.small),
                        SizedBox(height: 28),
                        SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4)),
                      ],
                    ),
                  ),
                ),
              ),
      );
}
