import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prices/application/asset_price_service.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/usd_try_rate_providers.dart';
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

  bool _refreshing = false;

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // The rates list is denominated in TRY independently of the dashboard region.
      if (_ref.read(usdTryRateProvider).rate == null) {
        await _ref.read(usdTryRateProvider.notifier).refresh();
      }
      final assets = _ref.read(allSupportedAssetsProvider).where((asset) =>
          asset.category == AssetCategory.crypto ||
          asset.category == AssetCategory.silver ||
          asset.category == AssetCategory.platinum ||
          asset.category == AssetCategory.metal).toList();
      final service = _ref.read(assetPriceServiceProvider);
      // Bounded concurrency: publish each batch rather than wait for every API.
      for (var i = 0; i < assets.length; i += 6) {
        final batch = assets.skip(i).take(6);
        final results = await Future.wait(batch.map((asset) async {
          if (asset.category == AssetCategory.crypto && asset.symbol != null) {
            final data = await service.fetchCrypto24hr(asset, useTry: true);
            if (data.price == null || data.price! <= 0) return (asset.id, null as CachedRateData?);
            return (asset.id, CachedRateData(
              lastPrice: data.price!, lastUpdated: DateTime.now(),
              dailyLow: data.low, dailyHigh: data.high, changePercent: data.changePercent,
            ));
          }
          final result = await service.fetchPrice(asset, useTry: true);
          if (result.price == null || result.price! <= 0) return (asset.id, null as CachedRateData?);
          return (asset.id, CachedRateData(lastPrice: result.price!, lastUpdated: result.lastUpdated));
        }));
        if (!mounted) return;
        final updated = Map<String, CachedRateData>.from(state);
        for (final (id, data) in results) {
          if (data != null) updated[id] = data;
        }
        state = updated;
      }
    } finally {
      _refreshing = false;
    }
  }

}

final ratesPricesCacheProvider =
    StateNotifierProvider<RatesPricesCacheNotifier, Map<String, CachedRateData>>((ref) {
  return RatesPricesCacheNotifier(ref);
});
