import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A restrained, warm-neutral design system inspired by iOS grouped surfaces.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkGoldTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF101113) : const Color(0xFFF3F2F0);
  final surface = dark ? const Color(0xFF1D1E21) : const Color(0xFFFFFFFF);
  final text = dark ? const Color(0xFFF5F3EF) : const Color(0xFF1F2228);
  final muted = dark ? const Color(0xFFA8A7A4) : const Color(0xFF777A80);
  final primary = dark ? const Color(0xFFE1C488) : const Color(0xFF866329);
  final separator = dark ? const Color(0xFF353639) : const Color(0xFFEAE8E4);
  final input = dark ? const Color(0xFF2A2B2F) : const Color(0xFFF2F1EF);
  final base = ThemeData(brightness: brightness, useMaterial3: true, fontFamily: 'Inter');
  final scheme = ColorScheme.fromSeed(
    seedColor: primary, brightness: brightness, primary: primary,
    surface: surface, onSurface: text, outline: muted, outlineVariant: separator,
    error: const Color(0xFFB34A47),
  );
  final textTheme = base.textTheme.apply(bodyColor: text, displayColor: text).copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -1.1),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
  );
  return base.copyWith(
    colorScheme: scheme, scaffoldBackgroundColor: background, textTheme: textTheme,
    cupertinoOverrideTheme: CupertinoThemeData(brightness: brightness, primaryColor: primary),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _SoftPageTransitionsBuilder(),
      TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: background, foregroundColor: text, surfaceTintColor: Colors.transparent,
      elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleSpacing: 20,
      toolbarHeight: 64, systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -1),
    ),
    cardTheme: CardThemeData(
      color: surface, surfaceTintColor: Colors.transparent, elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: input, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.2)),
      labelStyle: TextStyle(color: muted), hintStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: dark ? const Color(0xFFE1C488) : const Color(0xFF242832),
      foregroundColor: dark ? const Color(0xFF1B1B1B) : Colors.white,
      minimumSize: const Size(48, 48), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    )),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: dark ? const Color(0xFFE1C488) : const Color(0xFF242832),
      foregroundColor: dark ? const Color(0xFF1B1B1B) : Colors.white,
      elevation: 0, minimumSize: const Size(48, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: text, minimumSize: const Size(48, 48), side: BorderSide(color: separator),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: input, selectedColor: dark ? const Color(0xFF504737) : const Color(0xFFF0E8D9),
      side: BorderSide.none, showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface, selectedItemColor: primary, unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed, elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: dark ? const Color(0xFFE1C488) : const Color(0xFF242832),
      foregroundColor: dark ? const Color(0xFF1B1B1B) : Colors.white, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, showDragHandle: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    dividerColor: separator,
    listTileTheme: ListTileThemeData(textColor: text, iconColor: primary, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4)),
    snackBarTheme: SnackBarThemeData(backgroundColor: const Color(0xFF292B30), contentTextStyle: const TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}

/// Avoid the Android Cupertino parallax/black flash and respect reduced motion.
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return FadeTransition(opacity: animation.drive(CurveTween(curve: Curves.easeOut)), child: child);
  }
}
