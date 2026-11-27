import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:birikim_portfoy/src/app.dart';
import 'package:birikim_portfoy/src/features/prices/application/gold_price_providers.dart';
import 'package:birikim_portfoy/src/features/settings/application/settings_providers.dart';
import 'package:birikim_portfoy/src/features/transactions/application/transactions_providers.dart';
import 'package:birikim_portfoy/src/features/transactions/domain/investment_transaction.dart';

void main() {
  testWidgets('dark populated portfolio and market remain navigable on a small phone', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((request) async {
      if (request.url.host == 'api.frankfurter.app') return http.Response('{"rates":{"TRY":40}}', 200);
      if (request.url.host == 'api.metalpriceapi.com') return http.Response('{"success":true,"rates":{"XAU":0.0005,"USDXAU":2000,"XAG":0.02,"USDXAG":50,"XPT":0.001,"USDXPT":1000,"XPD":0.001,"USDXPD":1000}}', 200);
      return http.Response('{}', 503);
    });
    final container = ProviderContainer(overrides: [httpClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    addTearDown(client.close);
    container.read(appSettingsProvider.notifier).setThemeMode(AppThemeMode.darkGold);
    container.read(transactionsProvider.notifier).add(InvestmentTransaction(
      id: 'example', assetType: AssetType.gramAltin, amount: 10, unitPrice: 1500,
      dateTime: DateTime(2025, 1, 1), purchaseChannel: PurchaseChannel.bankaMobil,
    ));
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const BirikimPortfoyApp()));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    for (final label in ['Kurlar', 'Birikim', 'Hedefler', 'Diğer']) {
      await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text(label)));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: '$label ekranında hata');
    }
    await tester.tap(find.text('Ayarlar').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull, reason: 'Koyu ayarlar ekranında hata');
  });
}
