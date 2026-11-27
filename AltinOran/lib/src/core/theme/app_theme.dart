import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Altın Oran'ın ortak, sakin ve iOS esintili görsel dili.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);
ThemeData buildDarkGoldTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xFF111817) : const Color(0xFFF4F5F2);
  final surface = dark ? const Color(0xFF1C2623) : Colors.white;
  final text = dark ? const Color(0xFFF1F4F0) : const Color(0xFF1F2D29);
  final muted = dark ? const Color(0xFF9DADA6) : const Color(0xFF73817A);
  final primary = dark ? const Color(0xFFB6C9B8) : const Color(0xFF526E60);
  final separator = dark ? const Color(0xFF34413C) : const Color(0xFFE5EAE5);
  final input = dark ? const Color(0xFF25312D) : const Color(0xFFF3F5F2);
  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
    primary: primary,
    surface: surface,
    onSurface: text,
    outline: muted,
    outlineVariant: separator,
    error: const Color(0xFFBA625B),
  );
  final textTheme = base.textTheme.apply(bodyColor: text, displayColor: text).copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.2),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    bodySmall: base.textTheme.bodySmall?.copyWith(color: muted, height: 1.35),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      toolbarHeight: 60,
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: separator.withValues(alpha: dark ? 0.7 : 0.8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: input,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: primary, width: 1.3)),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
      backgroundColor: primary, foregroundColor: dark ? const Color(0xFF15211C) : Colors.white,
      minimumSize: const Size(48, 48), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontWeight: FontWeight.w600),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: primary, minimumSize: const Size(48, 48),
      side: BorderSide(color: separator),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    )),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: input,
      selectedColor: primary.withValues(alpha: 0.15),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primary, foregroundColor: dark ? const Color(0xFF15211C) : Colors.white, elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26)))),
    dividerColor: separator,
    listTileTheme: ListTileThemeData(textColor: text, iconColor: primary, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3)),
    snackBarTheme: SnackBarThemeData(backgroundColor: dark ? const Color(0xFF34433B) : const Color(0xFF283B32), contentTextStyle: const TextStyle(color: Colors.white), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
  );
}
