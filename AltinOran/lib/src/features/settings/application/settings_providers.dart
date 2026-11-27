import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/domain/investment_transaction.dart';

enum AppThemeMode {
  light,
  darkGold,
}

enum DisplayCurrency {
  tl,
  usd,
  eur,
}

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.displayCurrency,
    required this.defaultGramPurity,
    required this.biometricEnabled,
    required this.alarmBannerEnabled,
  });

  final AppThemeMode themeMode;
  final DisplayCurrency displayCurrency;
  final GoldPurity defaultGramPurity;
  final bool biometricEnabled;
  final bool alarmBannerEnabled;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    DisplayCurrency? displayCurrency,
    GoldPurity? defaultGramPurity,
    bool? biometricEnabled,
    bool? alarmBannerEnabled,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      displayCurrency: displayCurrency ?? this.displayCurrency,
      defaultGramPurity: defaultGramPurity ?? this.defaultGramPurity,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      alarmBannerEnabled: alarmBannerEnabled ?? this.alarmBannerEnabled,
    );
  }

  static const AppSettings initial = AppSettings(
    themeMode: AppThemeMode.darkGold,
    displayCurrency: DisplayCurrency.tl,
    defaultGramPurity: GoldPurity.carat24,
    biometricEnabled: false,
    alarmBannerEnabled: true,
  );
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(AppSettings.initial);

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void setDisplayCurrency(DisplayCurrency currency) {
    state = state.copyWith(displayCurrency: currency);
  }

  void setDefaultGramPurity(GoldPurity purity) {
    state = state.copyWith(defaultGramPurity: purity);
  }

  void setBiometricEnabled(bool enabled) {
    state = state.copyWith(biometricEnabled: enabled);
  }

  void setAlarmBannerEnabled(bool enabled) {
    state = state.copyWith(alarmBannerEnabled: enabled);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
  (ref) => AppSettingsNotifier(),
);

