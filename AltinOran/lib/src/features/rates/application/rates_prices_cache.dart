import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prices/application/asset_price_service.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/domain/gold_price.dart';
import '../../prices/domain/supported_asset.dart';

/// Kurlar sayfasında bir varlık için API'den gelen fiyat + isteğe bağlı günlük düşük/yüksek.
class CachedRateData {
  const CachedRateData({
    required this.lastPrice,
    required this.lastUpdated,
    this.buyPrice,
    this.sellPrice,
    this.dailyLow,
    this.dailyHigh,
    this.changePercent,
  });

  final double lastPrice;
  final DateTime lastUpdated;
  final double? buyPrice;
  final double? sellPrice;
  final double? dailyLow;
  final double? dailyHigh;
  final double? changePercent;
}

/// Kurlar listesi için API fiyatları önbelleği. Yenile veya sayfa açılışında doldurulur.
class RatesPricesCacheNotifier extends StateNotifier<Map<String, CachedRateData>> {
  RatesPricesCacheNotifier(this._ref) : super({});

  final Ref _ref;

  bool _useTry = true;

  Future<void> refresh() async {
    _useTry = _ref.read(selectedRegionProvider) == PriceRegion.turkey;
    final assets = _ref.read(allSupportedAssetsProvider);
    final service = _ref.read(assetPriceServiceProvider);
    final newMap = Map<String, CachedRateData>.from(state);

    for (final asset in assets) {
      if (asset.id == 'gold_gram') continue; // gold zaten goldPriceProvider'dan
      if (asset.category == AssetCategory.crypto && asset.symbol != null) {
        try {
          final data = await service.fetchCrypto24hr(asset, useTry: _useTry);
          if (data.price != null && data.price! > 0) {
            const spread = 0.002; // %0,2 kripto
            newMap[asset.id] = CachedRateData(
              lastPrice: data.price!,
              lastUpdated: DateTime.now(),
              buyPrice: data.price! * (1 - spread / 2),
              sellPrice: data.price! * (1 + spread / 2),
              dailyLow: data.low,
              dailyHigh: data.high,
              changePercent: data.changePercent,
            );
          }
        } catch (_) {}
        continue;
      }
      if (asset.id == 'fx_usd_try' || asset.id == 'fx_eur_try') continue; // kurlar provider'dan
      if (asset.category == AssetCategory.silver ||
          asset.category == AssetCategory.platinum ||
          asset.category == AssetCategory.metal) {
        try {
          final res = await service.fetchPrice(asset, useTry: _useTry);
          if (res.price != null && res.price! > 0) {
            const spread = 0.01; // %1 maden
            newMap[asset.id] = CachedRateData(
              lastPrice: res.price!,
              lastUpdated: res.lastUpdated,
              buyPrice: res.price! * (1 - spread / 2),
              sellPrice: res.price! * (1 + spread / 2),
            );
          }
        } catch (_) {}
      }
    }

    state = newMap;
  }
}

final ratesPricesCacheProvider =
    StateNotifierProvider<RatesPricesCacheNotifier, Map<String, CachedRateData>>((ref) {
  return RatesPricesCacheNotifier(ref);
});
