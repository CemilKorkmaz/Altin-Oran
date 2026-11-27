import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/supported_asset.dart';
import '../domain/gold_price.dart';
import 'api_config.dart';
import 'eur_try_rate_providers.dart';
import 'gold_price_providers.dart';
import 'metal_price_parser.dart';
import 'usd_try_rate_providers.dart';

/// Tek bir varlık için canlı fiyat sonucu (TL veya USD biriminde).
class AssetPriceResult {
  const AssetPriceResult({
    required this.price,
    required this.unitLabel,
    required this.lastUpdated,
    this.error,
  });

  final double? price;
  final String unitLabel;
  final DateTime lastUpdated;
  final String? error;
}

const _troyOunceToGram = 31.1034768;

/// Tüm varlıklar için canlı fiyat sağlayıcı.
/// Döviz: Frankfurter. Altın: Kapalıçarşı / MetalPriceAPI. Kripto: Binance. Gümüş/Platin/Paladyum: MetalPriceAPI.
final assetPriceServiceProvider = Provider<AssetPriceService>((ref) {
  return AssetPriceService(ref);
});

class AssetPriceService {
  AssetPriceService(this._ref);

  final Ref _ref;

  double? get _usdTryRate => _ref.read(usdTryRateProvider).rate;

  /// [asset] için fiyat döner. API'den veri gelmezse price: null, error dolu.
  Future<AssetPriceResult> fetchPrice(SupportedAsset asset, {required bool useTry}) async {
    if (asset.category == AssetCategory.crypto && asset.symbol != null) {
      return _fetchCryptoPrice(asset, useTry: useTry);
    }
    if (asset.id == 'gold_gram') {
      return _fetchGoldPrice(useTry: useTry);
    }
    if (asset.id == 'fx_usd_try' || asset.id == 'fx_eur_try') {
      return _fetchCurrencyPrice(asset, useTry: useTry);
    }
    if (asset.category == AssetCategory.silver ||
        asset.category == AssetCategory.platinum ||
        asset.category == AssetCategory.metal) {
      return _fetchMetalPrice(asset, useTry: useTry);
    }
    return AssetPriceResult(
      price: null,
      unitLabel: asset.unitLabel,
      lastUpdated: DateTime.now(),
      error: 'Fiyat alınamadı',
    );
  }

  /// Döviz: 1 USD veya 1 EUR = kaç TL (Frankfurter). Kur yoksa null.
  Future<AssetPriceResult> _fetchCurrencyPrice(SupportedAsset asset, {required bool useTry}) async {
    final usdRate = _ref.read(usdTryRateProvider).rate;
    final eurRate = _ref.read(eurTryRateProvider).rate;
    final unit = asset.id == 'fx_usd_try' ? 'USD' : 'EUR';
    if (asset.id == 'fx_usd_try') {
      if (useTry && usdRate == null) {
        return AssetPriceResult(price: null, unitLabel: unit, lastUpdated: DateTime.now(), error: 'Kur alınamadı');
      }
      return AssetPriceResult(
        price: useTry ? usdRate : 1.0,
        unitLabel: unit,
        lastUpdated: DateTime.now(),
      );
    }
    if (eurRate == null || (!useTry && (usdRate == null || usdRate <= 0))) {
      return AssetPriceResult(price: null, unitLabel: unit, lastUpdated: DateTime.now(), error: 'Kur alınamadı');
    }
    return AssetPriceResult(
      price: useTry ? eurRate : eurRate / usdRate!,
      unitLabel: unit,
      lastUpdated: DateTime.now(),
    );
  }

  Future<http.Response?> _fetchBinance(String path, String symbol) async {
    final client = _ref.read(httpClientProvider);
    for (final host in ['api.binance.com', 'api.binance.us']) {
      try {
        final response = await client.get(Uri.https(host, path, {'symbol': symbol}))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) return response;
      } catch (_) {
        // Try the next exchange endpoint.
      }
    }
    return null;
  }

  /// Binance public API: anlık fiyat (USDT).
  Future<AssetPriceResult> _fetchCryptoPrice(SupportedAsset asset, {required bool useTry}) async {
    final symbol = asset.symbol ?? '';
    try {
      final response = await _fetchBinance('/api/v3/ticker/price', symbol);
      if (response == null) return _cryptoError(asset);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final priceStr = body['price'] as String?;
      final usdPrice = double.tryParse(priceStr ?? '');
      if (usdPrice == null || usdPrice <= 0) {
        return _cryptoError(asset);
      }
      if (useTry) {
        final rate = _usdTryRate;
        if (rate == null) {
          return AssetPriceResult(price: null, unitLabel: asset.unitLabel, lastUpdated: DateTime.now(), error: 'USD/TRY kur alınamadı');
        }
        return AssetPriceResult(price: usdPrice * rate, unitLabel: asset.unitLabel, lastUpdated: DateTime.now());
      }
      return AssetPriceResult(price: usdPrice, unitLabel: asset.unitLabel, lastUpdated: DateTime.now());
    } catch (_) {
      return _cryptoError(asset);
    }
  }

  AssetPriceResult _cryptoError(SupportedAsset asset) {
    return AssetPriceResult(
      price: null,
      unitLabel: asset.unitLabel,
      lastUpdated: DateTime.now(),
      error: 'Canlı fiyat alınamadı',
    );
  }

  /// Kripto için 24s fiyat + düşük/yüksek (Binance ticker/24hr). Hata/veri yoksa price null.
  Future<({double? price, double? low, double? high, double? changePercent})> fetchCrypto24hr(
    SupportedAsset asset, {
    required bool useTry,
  }) async {
    final symbol = asset.symbol ?? '';
    try {
      final response = await _fetchBinance('/api/v3/ticker/24hr', symbol);
      if (response == null) return (price: null, low: null, high: null, changePercent: null);
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final lastStr = body['lastPrice'] as String?;
      final lowStr = body['lowPrice'] as String?;
      final highStr = body['highPrice'] as String?;
      final changeStr = body['priceChangePercent'] as String?;
      final last = double.tryParse(lastStr ?? '');
      if (last == null || last <= 0) return (price: null, low: null, high: null, changePercent: null);
      final low = double.tryParse(lowStr ?? '');
      final high = double.tryParse(highStr ?? '');
      final change = double.tryParse(changeStr ?? '');
      if (useTry) {
        final rate = _usdTryRate;
        if (rate == null) return (price: null, low: null, high: null, changePercent: null);
        return (
          price: last * rate,
          low: low != null ? low * rate : null,
          high: high != null ? high * rate : null,
          changePercent: change,
        );
      }
      return (price: last, low: low, high: high, changePercent: change);
    } catch (_) {
      return (price: null, low: null, high: null, changePercent: null);
    }
  }

  Future<AssetPriceResult> _fetchGoldPrice({required bool useTry}) async {
    final state = _ref.read(goldPriceProvider);
    final p = state.price?.pricePerGram;
    if (p != null) {
      final isTry = state.price!.region == PriceRegion.turkey;
      if (isTry == useTry) {
        return AssetPriceResult(price: p, unitLabel: 'gr', lastUpdated: state.price!.lastUpdated, error: state.errorMessage);
      }
      final rate = _usdTryRate;
      if (rate == null || rate <= 0) {
        return AssetPriceResult(price: null, unitLabel: 'gr', lastUpdated: DateTime.now(), error: 'USD/TRY kur alınamadı');
      }
      return AssetPriceResult(price: isTry ? p / rate : p * rate, unitLabel: 'gr', lastUpdated: state.price!.lastUpdated, error: state.errorMessage);
    }
    return AssetPriceResult(
      price: null,
      unitLabel: 'gr',
      lastUpdated: DateTime.now(),
      error: state.errorMessage ?? 'Fiyat alınamadı',
    );
  }

  /// Gümüş (XAG), platin (XPT), paladyum (XPD) — MetalPriceAPI USD + USD/TRY.
  Future<AssetPriceResult> _fetchMetalPrice(SupportedAsset asset, {required bool useTry}) async {
    final key = metalPriceApiKey;
    String? currencyCode;
    switch (asset.category) {
      case AssetCategory.silver:
        currencyCode = 'XAG';
        break;
      case AssetCategory.platinum:
        currencyCode = 'XPT';
        break;
      case AssetCategory.metal:
        if (asset.id != 'metal_palladium_gram') return _metalError(asset);
        currencyCode = 'XPD';
        break;
      default:
        return _metalError(asset);
    }
    if (key.isEmpty) {
      return _metalError(asset);
    }
    final uri = Uri.https(
      'api.metalpriceapi.com',
      '/v1/latest',
      {
        'api_key': key,
        'base': 'USD',
        'currencies': currencyCode,
      },
    );
    try {
      final client = _ref.read(httpClientProvider);
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return _metalError(asset);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        return _metalError(asset);
      }
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) return _metalError(asset);
      final pricePerOunce = metalPricePerOunce(rates, currencyCode, 'USD');
      if (pricePerOunce == null) return _metalError(asset);
      final price = asset.id.endsWith('_ons') ? pricePerOunce : pricePerOunce / _troyOunceToGram;
      if (useTry) {
        final rate = _usdTryRate;
        if (rate == null) {
          return AssetPriceResult(price: null, unitLabel: asset.unitLabel, lastUpdated: DateTime.now(), error: 'USD/TRY kur alınamadı');
        }
        return AssetPriceResult(price: price * rate, unitLabel: asset.unitLabel, lastUpdated: DateTime.now());
      }
      return AssetPriceResult(price: price, unitLabel: asset.unitLabel, lastUpdated: DateTime.now());
    } catch (_) {
      return _metalError(asset);
    }
  }

  AssetPriceResult _metalError(SupportedAsset asset) {
    return AssetPriceResult(
      price: null,
      unitLabel: asset.unitLabel,
      lastUpdated: DateTime.now(),
      error: 'Fiyat alınamadı',
    );
  }
}
