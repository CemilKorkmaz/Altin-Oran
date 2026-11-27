import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:birikim_portfoy/src/features/prices/application/asset_price_service.dart';
import 'package:birikim_portfoy/src/features/prices/application/gold_price_providers.dart';
import 'package:birikim_portfoy/src/features/prices/domain/supported_asset.dart';
import 'package:birikim_portfoy/src/features/prices/application/usd_try_rate_providers.dart';
import 'package:birikim_portfoy/src/features/prices/application/eur_try_rate_providers.dart';

void main() {
  test('falls back to Binance US when Binance is region blocked', () async {
    final hosts = <String>[];
    final client = MockClient((request) async {
      hosts.add(request.url.host);
      return request.url.host == 'api.binance.com'
          ? http.Response('{}', 451)
          : http.Response('{"price":"60000"}', 200);
    });
    final container = ProviderContainer(overrides: [httpClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    addTearDown(client.close);
    const btc = SupportedAsset(id: 'crypto_btc', name: 'Bitcoin', category: AssetCategory.crypto, symbol: 'BTCUSDT');
    final result = await container.read(assetPriceServiceProvider).fetchPrice(btc, useTry: false);
    expect(result.price, 60000);
    expect(hosts, ['api.binance.com', 'api.binance.us']);
  });

  test('metal quotes distinguish gram from troy ounce', () async {
    final client = MockClient((_) async => http.Response('{"success":true,"rates":{"XAG":0.02,"USDXAG":50}}', 200));
    final container = ProviderContainer(overrides: [httpClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    addTearDown(client.close);
    final service = container.read(assetPriceServiceProvider);
    const gram = SupportedAsset(id: 'silver_gram', name: 'Gümüş', category: AssetCategory.silver);
    const ounce = SupportedAsset(id: 'silver_ons', name: 'Ons Gümüş', category: AssetCategory.silver, unitLabel: 'ons');
    expect((await service.fetchPrice(ounce, useTry: false)).price, 50);
    expect((await service.fetchPrice(gram, useTry: false)).price, closeTo(50 / 31.1034768, 0.000001));
  });
  test('EUR in USD uses cross rate instead of reporting one dollar', () async {
    final client = MockClient((request) async => http.Response(
      request.url.queryParameters['from'] == 'EUR' ? '{"rates":{"TRY":45}}' : '{"rates":{"TRY":40}}', 200));
    final container = ProviderContainer(overrides: [httpClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    addTearDown(client.close);
    await Future.wait([container.read(usdTryRateProvider.notifier).refresh(), container.read(eurTryRateProvider.notifier).refresh()]);
    const euro = SupportedAsset(id: 'fx_eur_try', name: 'Euro', category: AssetCategory.currency);
    expect((await container.read(assetPriceServiceProvider).fetchPrice(euro, useTry: false)).price, closeTo(1.125, 0.000001));
  });

}
