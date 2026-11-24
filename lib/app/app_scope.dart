import 'package:flutter/widgets.dart';

import '../state/app_controller.dart';

/// Denetleyiciyi ağaca sağlar; değişince dinleyen ekranlar yeniden çizilir.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child}) : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
