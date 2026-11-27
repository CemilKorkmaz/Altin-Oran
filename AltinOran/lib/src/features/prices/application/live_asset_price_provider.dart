import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'asset_price_service.dart';
import 'gold_price_providers.dart';

/// Altın dışı canlı varlık (gümüş, platin, paladyum, kripto, döviz) için fiyat state'i.
class LiveNonGoldPriceState {
  const LiveNonGoldPriceState({
    this.assetId,
    this.useTry = true,
    this.result,
    this.isLoading = false,
  });

  final String? assetId;
  final bool useTry;
  final AssetPriceResult? result;
  final bool isLoading;
}

/// Seçilen canlı varlık (gold_gram değilse) için API'den fiyat çeker.
class LiveNonGoldPriceNotifier extends StateNotifier<LiveNonGoldPriceState> {
  LiveNonGoldPriceNotifier(this._ref)
      : super(const LiveNonGoldPriceState());

  final Ref _ref;

  Future<void> fetch(String assetId, bool useTry) async {
    if (assetId.isEmpty) return;
    state = LiveNonGoldPriceState(
      assetId: assetId,
      useTry: useTry,
      isLoading: true,
      result: state.assetId == assetId ? state.result : null,
    );
    final asset = _ref.read(supportedAssetByIdProvider(assetId));
    if (asset == null) {
      state = LiveNonGoldPriceState(
        assetId: assetId,
        useTry: useTry,
        isLoading: false,
        result: null,
      );
      return;
    }
    final service = _ref.read(assetPriceServiceProvider);
    final result = await service.fetchPrice(asset, useTry: useTry);
    if (mounted && state.assetId == assetId && state.useTry == useTry) {
      state = LiveNonGoldPriceState(
        assetId: assetId,
        useTry: useTry,
        isLoading: false,
        result: result,
      );
    }
  }
}

final liveNonGoldPriceProvider =
    StateNotifierProvider<LiveNonGoldPriceNotifier, LiveNonGoldPriceState>((ref) {
  return LiveNonGoldPriceNotifier(ref);
});
