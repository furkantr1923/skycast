import 'package:flutter/material.dart';

/// SKYCAST tasarım sistemi: yalnızca koyu tema.
class Sky {
  Sky._();

  static const bg = Color(0xFF060A13);
  static const bg2 = Color(0xFF0B1324);
  static const surface = Color(0x14FFFFFF);
  static const surfaceStrong = Color(0x22FFFFFF);
  static const stroke = Color(0x1FFFFFFF);
  static const text = Color(0xFFF2F6FC);
  static const textDim = Color(0xB3D5DEEC);
  static const textFaint = Color(0x80B8C4D6);
  static const accent = Color(0xFF5CB8FF);
  static const accent2 = Color(0xFF9D8CFF);
  static const warm = Color(0xFFFFB861);
  static const good = Color(0xFF4ADE80);
  static const danger = Color(0xFFF87171);

  static const radius = 22.0;
  static const radiusSm = 14.0;
  static const gap = 14.0;

  static ThemeData theme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: bg,
    ).copyWith(primary: accent, secondary: accent2, surface: bg2);
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: 'DMSans',
      scaffoldBackgroundColor: bg,
      splashFactory: InkSparkle.splashFactory,
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontFamily: 'DMSans', fontSize: 20, fontWeight: FontWeight.w600, color: text),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xF00A1120),
        indicatorColor: accent.withValues(alpha: 0.18),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontFamily: 'DMSans',
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? text : textDim,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF080E1B),
        indicatorColor: accent.withValues(alpha: 0.18),
        selectedLabelTextStyle: const TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w600, color: text),
        unselectedLabelTextStyle: const TextStyle(fontFamily: 'DMSans', color: textDim),
      ),
      cardTheme: const CardThemeData(color: surface, elevation: 0, margin: EdgeInsets.zero),
      dividerTheme: const DividerThemeData(color: stroke, thickness: 1, space: 1),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: accent.withValues(alpha: 0.22),
        side: const BorderSide(color: stroke),
        labelStyle: const TextStyle(fontFamily: 'DMSans', color: text, fontWeight: FontWeight.w500),
        shape: const StadiumBorder(),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textFaint),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusSm), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      sliderTheme: const SliderThemeData(trackHeight: 3, activeTrackColor: accent, thumbColor: Colors.white),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: Color(0xFF1A2438)),
      listTileTheme: const ListTileThemeData(iconColor: textDim, textColor: text),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : textDim),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? accent : surfaceStrong),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: textDim,
        indicatorColor: accent,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontFamily: 'DMSans', fontWeight: FontWeight.w600),
      ),
    );
  }

  static const h1 = TextStyle(fontSize: 88, fontWeight: FontWeight.w300, height: 1, letterSpacing: -3, color: text);
  static const title = TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: text);
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: textDim);
  static const body = TextStyle(fontSize: 15, color: text);
  static const small = TextStyle(fontSize: 12.5, color: textDim);
  static const tiny = TextStyle(fontSize: 11, color: textFaint);
}
