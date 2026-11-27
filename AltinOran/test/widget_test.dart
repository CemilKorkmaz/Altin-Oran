// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:birikim_portfoy/src/app.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    // Uygulamayı, production entrypoint'ine benzer şekilde başlat.
    await tester.pumpWidget(
      const ProviderScope(
        child: BirikimPortfoyApp(),
      ),
    );

    // Basit bir smoke test: en az bir MaterialApp bulunsun.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
