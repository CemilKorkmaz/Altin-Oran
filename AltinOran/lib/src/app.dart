import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/presentation/home_shell_page.dart';
import 'features/settings/application/settings_providers.dart';
import 'features/settings/presentation/biometric_gate.dart';

class BirikimPortfoyApp extends ConsumerWidget {
  const BirikimPortfoyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    final themeMode = switch (settings.themeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.darkGold => ThemeMode.dark,
    };

    return MaterialApp(
      title: 'Altın Oran',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoStretchScrollBehavior(),
      theme: buildLightTheme(),
      darkTheme: buildDarkGoldTheme(),
      themeMode: themeMode,
      home: settings.biometricEnabled
          ? const BiometricGate(child: HomeShellPage())
          : const HomeShellPage(),
    );
  }
}

class _NoStretchScrollBehavior extends MaterialScrollBehavior {
  const _NoStretchScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Kenarlarda parlama / gerilme (stretch) efektini tamamen kapat.
    return child;
  }
}

