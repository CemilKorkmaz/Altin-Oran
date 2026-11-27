import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../transactions/domain/investment_transaction.dart';
import '../domain/gold_price.dart';
import '../domain/supported_asset.dart';
import 'api_config.dart';
import 'bigpara_gold_api_client.dart';
import 'canlidoviz_client.dart';
import 'kapalicarsi_client.dart';
import 'metal_price_parser.dart';
import 'turkish_market_client.dart';

const _troyOunceToGram = 31.1034768;

final httpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// One shared request and cache for all screens. Never replaces good data with an error.
class TurkishMarketNotifier extends StateNotifier<TurkishMarketSnapshot?> {
  TurkishMarketNotifier(this._client) : super(null) {
    refresh();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }
  final TurkishMarketClient _client;
  late final Timer _timer;
  Future<TurkishMarketSnapshot?>? _inFlight;

  Future<TurkishMarketSnapshot?> refresh() {
    if (_inFlight != null) return _inFlight!;
    final pending = _load();
    _inFlight = pending;
    return pending.whenComplete(() { _inFlight = null; });
  }

  Future<TurkishMarketSnapshot?> _load() async {
    final result = await _client.fetch();
    if (mounted && result != null) state = result;
    return result;
  }

  @override
  void dispose() { _timer.cancel(); super.dispose(); }
}

final turkishMarketProvider = StateNotifierProvider<TurkishMarketNotifier, TurkishMarketSnapshot?>((ref) {
  return TurkishMarketNotifier(TurkishMarketClient(ref.read(httpClientProvider)));
});

final kapalicarsiClientProvider = Provider<KapalicarsiClient>((ref) {
  return KapalicarsiClient(ref.read(httpClientProvider));
});

final canlidovizClientProvider = Provider<CanlidovizClient>((ref) {
  return CanlidovizClient(ref.read(httpClientProvider));
});

final bigparaGoldApiClientProvider = Provider<BigparaGoldApiClient>((ref) {
  return BigparaGoldApiClient(ref.read(httpClientProvider));
});

/// Bigpara API'dan gelen tüm byKey verisi (gram_altin, ceyrek, yarim, silver_gram, ons, vb.). Kurlar sayfası yenilendiğinde güncellenir.
class BigparaByKeyNotifier extends StateNotifier<Map<String, Map<String, dynamic>>?> {
  BigparaByKeyNotifier(this._ref) : super(null);
  final Ref _ref;

  Future<void> refresh() async {
    final client = _ref.read(bigparaGoldApiClientProvider);
    final byKey = await client.fetchAllByKey();
    state = byKey;
  }
}

final bigparaByKeyProvider = StateNotifierProvider<BigparaByKeyNotifier, Map<String, Map<String, dynamic>>?>((ref) {
  return BigparaByKeyNotifier(ref);
});

PriceRegion regionForSource(PriceSource source) {
  switch (source) {
    case PriceSource.kapalicarsi:
    case PriceSource.bankalar:
      return PriceRegion.turkey;
    case PriceSource.kitco:
    case PriceSource.comex:
    case PriceSource.bloomberg:
      return PriceRegion.usa;
  }
}

final selectedRegionProvider = StateProvider<PriceRegion>((ref) {
  return PriceRegion.turkey;
});

/// Canlı kartında hangi varlık seçili (asset id).
final selectedLiveAssetIdProvider = StateProvider<String>((ref) => 'gold_gram');

/// Gram altın seçiliyken hangi ayar gösterilsin (ana sayfa canlı kart).
final selectedGramGoldPurityProvider = StateProvider<GoldPurity>((ref) => GoldPurity.carat24);

/// Canlı kartında gösterilecek varlık id'leri. İlk üç: gram altın, gram gümüş, gram platin.
final liveSelectedAssetIdsProvider = StateProvider<List<String>>((ref) => [
  'gold_gram',
  'silver_gram',
  'platinum_gram',
  // Dövizler de varsayılan listede görünsün.
  'fx_usd_try',
  'fx_eur_try',
]);

/// Kullanıcının eklediği "başka coin" varlıkları (Binance symbol ile).
final customCoinsProvider = StateProvider<List<SupportedAsset>>((ref) => []);

/// Tüm varlık kataloğu: ön tanımlı + kullanıcının eklediği coinler.
/// Custom boşken aynı liste referansı dönülür; sürekli yeni liste ile rebuild döngüsü önlenir.
final allSupportedAssetsProvider = Provider<List<SupportedAsset>>((ref) {
  final custom = ref.watch(customCoinsProvider);
  if (custom.isEmpty) return predefinedSupportedAssets;
  return [...predefinedSupportedAssets, ...custom];
});

/// Asset id ile SupportedAsset bulur.
final supportedAssetByIdProvider = Provider.family<SupportedAsset?, String>((ref, id) {
  final all = ref.watch(allSupportedAssetsProvider);
  try {
    return all.firstWhere((a) => a.id == id);
  } catch (_) {
    return null;
  }
});

class GoldPriceNotifier extends StateNotifier<GoldPriceState> {
  GoldPriceNotifier(this._ref) : super(GoldPriceState.initial()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    final region = _ref.read(selectedRegionProvider);
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newPrice = await _fetchFromApi(region);
      if (!mounted || _ref.read(selectedRegionProvider) != region) return;
      state = GoldPriceState(
        isLoading: false,
        price: newPrice,
        previousPrice: state.price?.region == region ? state.price : newPrice,
      );
    } catch (e, st) {
      if (!mounted || _ref.read(selectedRegionProvider) != region) return;
      if (kDebugMode) {
        debugPrint('Altın: tüm kaynaklar başarısız — $e');
        debugPrint(st.toString());
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Fiyat alınamadı',
      );
    }
  }

  void useMarketSnapshot(TurkishMarketSnapshot? market) {
    if (market == null || _ref.read(selectedRegionProvider) != PriceRegion.turkey) return;
    final value = market.quotes['gold_gram']?.price;
    if (value == null) return;
    final previous = state.price?.region == PriceRegion.turkey ? state.price : null;
    state = GoldPriceState(isLoading: false, previousPrice: previous,
      price: GoldPrice(region: PriceRegion.turkey, pricePerGram: value,
        pricePerOunce: value * _troyOunceToGram, lastUpdated: market.updatedAt, source: 'Gramhane'));
  }

  /// Test ve geliştirme sırasında gram altın fiyatını manuel ayarlamak için.
  /// Örn: yenile tuşuna 3 kez basıldığında ₺2502 yapmak gibi.
  void setDebugPricePerGram(double gramPrice) {
    final old = state.price ??
        GoldPrice(
          region: PriceRegion.turkey,
          pricePerGram: gramPrice,
          pricePerOunce: gramPrice * _troyOunceToGram,
          lastUpdated: DateTime.now(),
        );
    final newPrice = GoldPrice(
      region: old.region,
      pricePerGram: gramPrice,
      pricePerOunce: old.pricePerOunce,
      lastUpdated: DateTime.now(),
    );
    state = GoldPriceState(
      isLoading: false,
      price: newPrice,
      previousPrice: state.price ?? newPrice,
    );
  }

  Future<GoldPrice> _fetchFromApi(PriceRegion region) async {
    // 1) Türkiye: Önce Bigpara gold-api (HTML parse backend), sonra CanliDoviz, Kapalıçarşı, MetalPriceAPI+Frankfurter
    if (region == PriceRegion.turkey) {
      final market = await _ref.read(turkishMarketProvider.notifier).refresh();
      final quote = market?.quotes['gold_gram'];
      if (market != null && quote?.price != null) {
        final price = quote!.price!;
        return GoldPrice(region: region, pricePerGram: price, pricePerOunce: price * _troyOunceToGram,
          lastUpdated: market.updatedAt, source: 'Gramhane');
      }
      final bigpara = _ref.read(bigparaGoldApiClientProvider);
      final gramTryBigpara = await bigpara.fetchGramAltinTry();
      if (kDebugMode && (gramTryBigpara == null || gramTryBigpara <= 0)) {
        debugPrint('Altın: Bigpara gold-api veri yok veya URL boş');
      }
      if (gramTryBigpara != null && gramTryBigpara > 0) {
        return GoldPrice(
          region: PriceRegion.turkey,
          pricePerGram: gramTryBigpara,
          pricePerOunce: gramTryBigpara * _troyOunceToGram,
          lastUpdated: DateTime.now(),
        );
      }
      final canlidoviz = _ref.read(canlidovizClientProvider);
      final gramTry = await canlidoviz.fetchGramAltinTry();
      if (kDebugMode && (gramTry == null || gramTry <= 0)) {
        debugPrint('Altın: CanliDoviz veri yok veya hata');
      }
      if (gramTry != null && gramTry > 0) {
        return GoldPrice(
          region: PriceRegion.turkey,
          pricePerGram: gramTry,
          pricePerOunce: gramTry * _troyOunceToGram,
          lastUpdated: DateTime.now(),
        );
      }
      final kapalicarsi = _ref.read(kapalicarsiClientProvider);
      final gramTryK = await kapalicarsi.fetchGramAltinTry();
      if (kDebugMode && (gramTryK == null || gramTryK <= 0)) {
        debugPrint('Altın: Kapalıçarşı veri yok veya hata');
      }
      if (gramTryK != null && gramTryK > 0) {
        return GoldPrice(
          region: PriceRegion.turkey,
          pricePerGram: gramTryK,
          pricePerOunce: gramTryK * _troyOunceToGram,
          lastUpdated: DateTime.now(),
        );
      }
      // 2) Türkiye yedek: MetalPriceAPI (USD bazlı XAU) + Frankfurter USD/TRY → gram TL
      final goldTry = await _fetchGoldTryViaUsd();
      if (kDebugMode && goldTry == null) {
        debugPrint('Altın: MetalPriceAPI+Frankfurter yedek yolu veri döndürmedi');
      }
      if (goldTry != null) {
        return GoldPrice(
          region: PriceRegion.turkey,
          pricePerGram: goldTry,
          pricePerOunce: goldTry * _troyOunceToGram,
          lastUpdated: DateTime.now(),
        );
      }
    }

    // 3) MetalPriceAPI (key varsa) — doğrudan TRY veya USD
    final apiKey = metalPriceApiKey;
    if (apiKey.isNotEmpty) {
      final baseCurrency = switch (region) {
        PriceRegion.turkey => 'TRY',
        PriceRegion.usa => 'USD',
      };
      final price = await _fetchMetalPriceApi(apiKey, baseCurrency, region);
      if (price != null) return price;
    }

    // 4) Son deneme: USD bazlı XAU + USD/TRY (Türkiye için zaten denendi; USA için sadece USD)
    if (region == PriceRegion.usa) {
      final priceUsd = await _fetchGoldUsdViaMetalPriceApi();
      if (priceUsd != null) return priceUsd;
    }

    throw Exception('Fiyat alınamadı');
  }

  /// MetalPriceAPI: base=USD, XAU → ons başına USD; Frankfurter → USD/TRY. Gram TL döner.
  Future<double?> _fetchGoldTryViaUsd() async {
    final apiKey = metalPriceApiKey;
    if (apiKey.isEmpty) return null;
    final pricePerOunceUsd = await _fetchXauPricePerOunceInUsd(apiKey);
    if (pricePerOunceUsd == null || pricePerOunceUsd <= 0) return null;
    final usdTry = await _fetchUsdTryRate();
    if (usdTry == null || usdTry <= 0) return null;
    final pricePerGramUsd = pricePerOunceUsd / _troyOunceToGram;
    return pricePerGramUsd * usdTry;
  }

  /// Frankfurter ile USD/TRY (döngüsel import olmaması için burada).
  Future<double?> _fetchUsdTryRate() async {
    try {
      final client = _ref.read(httpClientProvider);
      final uri = Uri.https('api.frankfurter.app', '/latest', {'from': 'USD', 'to': 'TRY'});
      final response = await client.get(uri).timeout(const Duration(seconds: 8));
      if (kDebugMode && response.statusCode != 200) {
        debugPrint('Altın: Frankfurter HTTP ${response.statusCode}');
      }
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null || !rates.containsKey('TRY')) return null;
      final tryRate = rates['TRY'];
      if (tryRate is num) return tryRate.toDouble();
      if (tryRate is String) return double.tryParse(tryRate.replaceAll(',', '.'));
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('Altın: Frankfurter hata — $e');
      return null;
    }
  }

  /// MetalPriceAPI base=USD, currencies=XAU → ons başına USD. Oran genelde "1 USD = X XAU" (küçük sayı).
  Future<double?> _fetchXauPricePerOunceInUsd(String apiKey) async {
    try {
      final client = _ref.read(httpClientProvider);
      final uri = Uri.https(
        'api.metalpriceapi.com',
        '/v1/latest',
        {'api_key': apiKey, 'base': 'USD', 'currencies': 'XAU'},
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (kDebugMode && response.statusCode != 200) {
        debugPrint('Altın: MetalPriceAPI HTTP ${response.statusCode} — ${response.statusCode == 429 ? "limit aşımı olabilir" : ""}');
      }
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) return null;
      return metalPricePerOunce(rates, 'XAU', 'USD');
    } catch (e) {
      if (kDebugMode) debugPrint('Altın: MetalPriceAPI hata — $e');
      return null;
    }
  }

  /// MetalPriceAPI ile doğrudan TRY veya USD bazlı XAU fiyatı.
  Future<GoldPrice?> _fetchMetalPriceApi(String apiKey, String baseCurrency, PriceRegion region) async {
    try {
      final client = _ref.read(httpClientProvider);
      final uri = Uri.https(
        'api.metalpriceapi.com',
        '/v1/latest',
        {'api_key': apiKey, 'base': baseCurrency, 'currencies': 'XAU'},
      );
      final response = await client.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) return null;
      final rates = body['rates'] as Map<String, dynamic>?;
      if (rates == null) return null;
      final pricePerOunce = metalPricePerOunce(rates, 'XAU', baseCurrency);
      if (pricePerOunce == null) return null;
      final ts = body['timestamp'] as int?;
      final lastUpdated = ts != null ? DateTime.fromMillisecondsSinceEpoch(ts * 1000) : DateTime.now();
      final pricePerGram = pricePerOunce / _troyOunceToGram;
      return GoldPrice(
        region: region,
        pricePerGram: pricePerGram,
        pricePerOunce: pricePerOunce,
        lastUpdated: lastUpdated,
      );
    } catch (_) {
      return null;
    }
  }

  /// Sadece USD bölgesi: MetalPriceAPI USD bazlı XAU.
  Future<GoldPrice?> _fetchGoldUsdViaMetalPriceApi() async {
    final apiKey = metalPriceApiKey;
    if (apiKey.isEmpty) return null;
    final pricePerOunceUsd = await _fetchXauPricePerOunceInUsd(apiKey);
    if (pricePerOunceUsd == null || pricePerOunceUsd <= 0) return null;
    return GoldPrice(
      region: PriceRegion.usa,
      pricePerGram: pricePerOunceUsd / _troyOunceToGram,
      pricePerOunce: pricePerOunceUsd,
      lastUpdated: DateTime.now(),
    );
  }
}

final goldPriceProvider =
    StateNotifierProvider<GoldPriceNotifier, GoldPriceState>((ref) {
  final notifier = GoldPriceNotifier(ref);
  ref.listen<TurkishMarketSnapshot?>(turkishMarketProvider, (_, next) => notifier.useMarketSnapshot(next));
  return notifier;
});

