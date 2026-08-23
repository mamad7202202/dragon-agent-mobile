import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Ember-lit dragon theme — dark charcoal canvas with molten-orange accents.
class DragonColors {
  static const bg = Color(0xFF0B0C10);
  static const surface = Color(0xFF14161C);
  static const card = Color(0xFF1A1D26);
  static const stroke = Color(0x14FFFFFF);
  static const ember = Color(0xFFFF6A3D);
  static const emberDeep = Color(0xFFE5484D);
  static const gold = Color(0xFFFFC53D);
  static const textPrimary = Color(0xFFF2F3F5);
  static const textDim = Color(0xFF9AA3AF);
  static const success = Color(0xFF46C07A);

  static const emberGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A5B), ember, emberDeep],
  );

  // light theme
  static const bgLight = Color(0xFFF7F5F2);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const textPrimaryLight = Color(0xFF191B20);
  static const textDimLight = Color(0xFF6B7280);
}

ThemeData buildDragonTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DragonColors.ember,
    brightness: brightness,
  ).copyWith(
    primary: DragonColors.ember,
    secondary: DragonColors.gold,
    error: DragonColors.emberDeep,
    surface: isDark ? DragonColors.surface : DragonColors.surfaceLight,
    onSurface: isDark ? DragonColors.textPrimary : DragonColors.textPrimaryLight,
  );

  final fg = isDark ? DragonColors.textPrimary : DragonColors.textPrimaryLight;
  final dim = isDark ? DragonColors.textDim : DragonColors.textDimLight;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? DragonColors.bg : DragonColors.bgLight,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: fg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: fg,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? DragonColors.card : DragonColors.surfaceLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isDark ? DragonColors.stroke : const Color(0x12000000)),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? DragonColors.card : const Color(0xFFF1EFEC),
      hintStyle: TextStyle(color: dim.withValues(alpha: 0.7)),
      labelStyle: TextStyle(color: dim),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DragonColors.ember, width: 1.4),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: isDark ? DragonColors.stroke : const Color(0x10000000),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? DragonColors.card : const Color(0xFF22252E),
      contentTextStyle: const TextStyle(color: Colors.white),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: DragonColors.ember,
      thumbColor: DragonColors.ember,
      inactiveTrackColor: dim.withValues(alpha: 0.25),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Colors.white : dim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? DragonColors.ember : (isDark ? DragonColors.card : const Color(0xFFE4E1DD)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? DragonColors.surface : DragonColors.surfaceLight,
      indicatorColor: DragonColors.ember.withValues(alpha: 0.18),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    textTheme: TextTheme(
      headlineMedium: TextStyle(color: fg, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      titleLarge: TextStyle(color: fg, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      titleMedium: TextStyle(color: fg, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: fg),
      bodyMedium: TextStyle(color: fg, height: 1.45),
      bodySmall: TextStyle(color: dim),
      labelSmall: TextStyle(color: dim, letterSpacing: 0.3),
    ),
  );
}
