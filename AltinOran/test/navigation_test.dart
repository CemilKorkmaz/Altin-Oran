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
    final bar = find.byType(BottomNavigationBar);
    await tester.tap(find.descendant(of: bar, matching: find.text('Kurlar')));
    await tester.pump();
    await tester.tap(find.text('Kripto').first);
    await tester.pump();
    expect(find.text('Bitcoin'), findsWidgets);
    await tester.tap(find.descendant(of: bar, matching: find.text('Hedefler')));
    await tester.pump();
    await tester.tap(find.descendant(of: bar, matching: find.text('Kurlar')));
    await tester.pump();
    expect(find.text('Bitcoin'), findsWidgets, reason: 'Sekme filtresi korunmalı');
    expect(tester.takeException(), isNull);
    for (final label in ['Kurlar', 'Birikim', 'Hedefler', 'Diğer']) {
      final nav = find.byType(BottomNavigationBar);
      await tester.tap(find.descendant(of: nav, matching: find.text(label)));
      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.takeException(), isNull, reason: '$label ekranında hata');
    }
    for (final page in ['İstatistikler', 'Ayarlar']) {
      await tester.tap(find.text(page).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '$page ekranında hata');
      await tester.pageBack();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.tap(find.descendant(of: find.byType(BottomNavigationBar), matching: find.text('Ana sayfa')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });
}
