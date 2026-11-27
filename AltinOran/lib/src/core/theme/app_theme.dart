import 'package:flutter/material.dart';

ThemeData buildLightTheme() {
  // Biraz koyu altın sarısı / krem arka plan; kâr barı ve kartlar daha net görünsün.
  const primaryColor = Color(0xFFB8860B); // koyu altın (dark goldenrod)
  const primaryLight = Color(0xFFD4A84B); // orta altın
  const accentColor = Color(0xFF8B6914); // derin altın / vurgu
  const background = Color(0xFFEDE4D4); // koyu krem / buğday
  const surface = Color(0xFFF5EDE0); // kartlar: belirgin krem
  const surfaceVariant = Color(0xFFE8DCC8); // input / ikincil yüzey
  const onBackground = Color(0xFF2C2416); // koyu kahve metin
  const onSurface = Color(0xFF3D3426); // kart üstü metin
  const outline = Color(0xFFB8A88A); // çerçeve / border (biraz koyu)

  final base = ThemeData.light(useMaterial3: true);

  final colorScheme = ColorScheme.light(
    primary: primaryColor,
    onPrimary: Colors.white,
    primaryContainer: primaryLight.withOpacity(0.25),
    secondary: accentColor,
    onSecondary: Colors.white,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    error: const Color(0xFFB91C1C),
    onError: Colors.white,
    outline: outline,
  );

  return base.copyWith(
    colorScheme: colorScheme.copyWith(
      surface: surface,
      onSurface: onSurface,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: onBackground,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: onBackground),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 1,
      shadowColor: primaryColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: onBackground,
      displayColor: onBackground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: outline, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: onSurface),
      hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primaryColor,
      unselectedItemColor: onSurface.withOpacity(0.6),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    dividerColor: outline.withOpacity(0.5),
    listTileTheme: ListTileThemeData(
      textColor: onSurface,
      iconColor: primaryColor,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: onBackground,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData buildDarkGoldTheme() {
  const primary = Color(0xFFFACC15); // parlak altın / sarı
  const secondary = Color(0xFFEAB308);
  const background = Color(0xFF111827); // lacivert-siyah arka plan
  const surface = Color(0xFF020617); // kartlar için daha koyu
  const surfaceVariant = Color(0xFF1E293B);
  const onBackground = Color(0xFFF9FAFB);
  const onSurface = Color(0xFFE5E7EB);
  const outline = Color(0xFF4B5563);

  final base = ThemeData.dark(useMaterial3: true);

  final scheme = ColorScheme.dark(
    primary: primary,
    onPrimary: Colors.black,
    primaryContainer: primary.withOpacity(0.18),
    secondary: secondary,
    onSecondary: Colors.black,
    surface: surface,
    onSurface: onSurface,
    surfaceContainerHighest: surfaceVariant,
    background: background,
    onBackground: onBackground,
    outline: outline,
    error: const Color(0xFFEF4444),
    onError: Colors.black,
  );

  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: onBackground,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: onBackground,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: const IconThemeData(color: onBackground),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline.withOpacity(0.6)),
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: onBackground,
      displayColor: onBackground,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceVariant,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: outline.withOpacity(0.6), width: 1),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(color: onSurface),
      hintStyle: TextStyle(color: onSurface.withOpacity(0.7)),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: onSurface.withOpacity(0.7),
      type: BottomNavigationBarType.fixed,
      elevation: 12,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.black,
      elevation: 6,
    ),
    dividerColor: outline.withOpacity(0.6),
    listTileTheme: ListTileThemeData(
      textColor: onSurface,
      iconColor: primary,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.black.withOpacity(0.9),
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

