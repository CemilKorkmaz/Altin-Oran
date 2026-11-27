import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:birikim_portfoy/src/app.dart';
import 'package:birikim_portfoy/src/features/prices/application/gold_price_providers.dart';

void main() {
  testWidgets('small phone can open every main tab without overflow', (tester) async {
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) { FlutterError.dumpErrorToConsole(details, forceReport: true); originalOnError?.call(details); };
    addTearDown(() => FlutterError.onError = originalOnError);
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final client = MockClient((_) async => http.Response('{}', 503));
    addTearDown(client.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [httpClientProvider.overrideWithValue(client)],
      child: const BirikimPortfoyApp(),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    for (final label in ['Kurlar', 'Birikim', 'İstatistik', 'Hedefler', 'Ayarlar', 'Ana sayfa']) {
      final nav = find.byType(BottomNavigationBar);
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: '$label ekranında hata');
    }
  });
}
