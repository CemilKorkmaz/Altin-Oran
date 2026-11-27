import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birikim_portfoy/src/features/prices/application/turkish_market_client.dart';
import 'package:birikim_portfoy/src/features/prices/application/gold_price_providers.dart';
import 'package:birikim_portfoy/src/features/rates/presentation/rates_page.dart';
import 'package:birikim_portfoy/src/features/prices/domain/gold_price.dart';

Map<String, dynamic> payload({String? timestamp}) => {
  'meta': {'status': 'success', 'tarih': timestamp ?? DateTime.now().toUtc().add(const Duration(hours: 3)).toIso8601String().substring(0, 19).replaceFirst('T', ' ')},
  'kurlar': {'ALTIN': {'alis': 6000.0, 'satis': 6010.0, 'yuzde': 1.2}, 'ONS': {'satis': 3500}, 'GUMUS': {'alis': 80, 'satis': 81}},
  'ziynet_ve_diger': {'Çeyrek (Yeni)': {'alis': 9500.0, 'satis': 9700.0}, 'Yarım (Yeni)': {'alis': 19000, 'satis': 19400}, '22 Ayar Bilezik': {'alis': 5500, 'satis': 5600}},
};

void main() {
  test('parses real bid and ask, leaves dollar ounce out of TRY quotes', () {
    final snapshot = TurkishMarketClient.parse(jsonEncode(payload()));
    expect(snapshot, isNotNull);
    expect(snapshot!.quotes['gold_gram']!.buy, 6000);
    expect(snapshot.quotes['gold_gram']!.sell, 6010);
    expect(snapshot.quotes['gold_ceyrek']!.price, 9700);
    expect(snapshot.quotes['silver_gram']!.price, 81);
    expect(snapshot.quotes['gold_ons'], isNull);
    expect(snapshot.isDelayed, false);
  });
  test('converts Istanbul time and marks old data delayed', () {
    final snapshot = TurkishMarketClient.parse(jsonEncode(payload(timestamp: '2025-01-01 03:00:00')))!;
    expect(snapshot.updatedAt.toUtc(), DateTime.utc(2025, 1, 1));
    expect(snapshot.isDelayed, true);
  });
  test('rejects broken, unsuccessful, future and invalid prices', () {
    final bad = payload();
    (bad['kurlar'] as Map)['ALTIN'] = {'satis': -1, 'alis': 0};
    expect(TurkishMarketClient.parse(jsonEncode(bad)), isNull);
    expect(TurkishMarketClient.parse('{invalid'), isNull);
    final future = payload(timestamp: '2099-01-01 00:00:00');
    expect(TurkishMarketClient.parse(jsonEncode(future)), isNull);
    final failed = payload();
    (failed['meta'] as Map)['status'] = 'error';
    expect(TurkishMarketClient.parse(jsonEncode(failed)), isNull);
  });
  test('USD gold is converted before being displayed in a TRY portfolio', () {
    final gold = GoldPrice(region: PriceRegion.usa, pricePerGram: 100, pricePerOunce: 3110, lastUpdated: DateTime.now());
    expect(goldPricePerGramInTry(gold, 40), 4000);
    expect(goldPricePerGramInTry(gold, null), isNull);
  });
  test('shared quote populates rates list and portfolio gold provider', () async {
    var calls = 0;
    final client = MockClient((request) async {
      if (request.url.host == 'api.gramhane.com') { calls++; return http.Response(jsonEncode(payload()), 200, headers: {'content-type': 'application/json; charset=utf-8'}); }
      return http.Response('{}', 503);
    });
    final container = ProviderContainer(overrides: [httpClientProvider.overrideWithValue(client)]);
    addTearDown(client.close);
    addTearDown(container.dispose);
    container.read(goldPriceProvider);
    final snapshot = await container.read(turkishMarketProvider.notifier).refresh();
    expect(snapshot, isNotNull);
    final rates = container.read(ratesListProvider);
    final gram = rates.firstWhere((r) => r.id == 'gold_gram');
    final quarter = rates.firstWhere((r) => r.id == 'gold_ceyrek');
    expect(gram.lastPrice, 6010);
    expect(gram.buyPrice, 6000);
    expect(quarter.sellPrice, 9700);
    expect(quarter.subtitle, 'Gramhane');
    expect(container.read(goldPriceProvider).price?.pricePerGram, 6010);
    expect(calls, 1);
  });
}
