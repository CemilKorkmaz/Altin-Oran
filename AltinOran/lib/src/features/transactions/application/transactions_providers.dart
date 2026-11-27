import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/application/eur_try_rate_providers.dart';
import '../domain/investment_transaction.dart';

/// Uygulama içi tüm işlemleri tutan provider.
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, List<InvestmentTransaction>>(
  (ref) => TransactionsNotifier(),
);

class TransactionsNotifier extends StateNotifier<List<InvestmentTransaction>> {
  TransactionsNotifier() : super(const []);

  void add(InvestmentTransaction tx) {
    state = [...state, tx];
  }

  void update(InvestmentTransaction updated) {
    state = [
      for (final tx in state) if (tx.id == updated.id) updated else tx,
    ];
  }

  void remove(String id) {
    state = state.where((tx) => tx.id != id).toList(growable: false);
  }

  /// Tüm işlemleri verilen liste ile değiştirir (içe aktarma için).
  void replaceAll(List<InvestmentTransaction> list) {
    state = List<InvestmentTransaction>.from(list);
  }
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.totalCost,
    required this.totalCurrentValue,
    required this.totalProfitLoss,
    required this.realizedProfitLoss,
    required this.unrealizedProfitLoss,
    required this.profitLossPerAsset,
  });

  /// Açık pozisyonların toplam maliyeti (seçili para birimi cinsinden).
  final double totalCost;

  /// Açık pozisyonların güncel toplam değeri (canlı fiyata göre).
  /// Canlı fiyat yoksa 0 olabilir.
  final double totalCurrentValue;

  /// Gerçekleşmiş + gerçekleşmemiş toplam kâr/zarar.
  final double totalProfitLoss;

  /// Sadece gerçekleşmiş (satışlardan gelen) kâr/zarar.
  final double realizedProfitLoss;

  /// Güncel altın fiyatına göre açık pozisyonlardan doğan potansiyel kâr/zarar.
  final double unrealizedProfitLoss;

  /// Her bir varlık türü için toplam (gerçekleşmiş + gerçekleşmemiş) kâr/zarar.
  /// Anahtar: [AssetType], Değer: ilgili varlık için toplam kâr/zarar.
  final Map<AssetType, double> profitLossPerAsset;
}

/// İlgili işlemin ne kadarını \"saf gram altın eşdeğeri\" olarak sayacağımızı hesaplar.
double _goldGramsForTransaction(InvestmentTransaction tx) {
  return tx.goldEquivalentGrams;
}

/// Toplam maliyet + canlı altın fiyatına göre kâr/zarar özetini hesaplayan provider.
final portfolioSummaryProvider = Provider<PortfolioSummary>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final goldState = ref.watch(goldPriceProvider);

  final currentGramPrice = goldState.price?.pricePerGram;
  final usdRate = ref.watch(usdTryRateProvider).rate;
  final eurRate = ref.watch(eurTryRateProvider).rate;
  final currentFxPricePerUnit = <AssetType, double>{};
  if (usdRate != null) currentFxPricePerUnit[AssetType.usd] = usdRate;
  if (eurRate != null) currentFxPricePerUnit[AssetType.eur] = eurRate;

  // Her varlık türü için ortalama maliyet ve gram takibi.
  final Map<AssetType, double> remainingGramsPerAsset = {};
  final Map<AssetType, double> remainingCostPerAsset = {};

  // Varlık bazında gerçekleşmiş kâr/zarar.
  final Map<AssetType, double> realizedProfitLossPerAsset = {};

  double realizedProfitLoss = 0;

  // İşlemleri kronolojik sıraya göre dolaş.
  final sorted = [...transactions]
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  for (final tx in sorted) {
    final grams = _goldGramsForTransaction(tx);
    if (grams == 0) continue;

    final asset = tx.assetType;
    final remainingGrams = remainingGramsPerAsset[asset] ?? 0;
    final remainingCost = remainingCostPerAsset[asset] ?? 0;

    if (tx.direction == TransactionDirection.buy) {
      remainingGramsPerAsset[asset] = remainingGrams + grams;
      remainingCostPerAsset[asset] = remainingCost + tx.totalValue;
    } else {
      if (remainingGrams <= 0) {
        // Hiç pozisyon yokken satış yapıldıysa, tamamını kâr olarak sayma.
        // Basit tutmak için bu durumu yok sayıyoruz.
        continue;
      }

      final sellGrams = grams.clamp(0, remainingGrams);
      final avgCostPerGram =
          remainingGrams > 0 ? (remainingCost / remainingGrams) : 0;
      final costRemoved = sellGrams * avgCostPerGram;
      final saleProceeds = (tx.totalValue / grams) * sellGrams;
      final realizedForThisTx = saleProceeds - costRemoved;

      realizedProfitLoss += realizedForThisTx;
      realizedProfitLossPerAsset[asset] =
          (realizedProfitLossPerAsset[asset] ?? 0) + realizedForThisTx;

      remainingGramsPerAsset[asset] = remainingGrams - sellGrams;
      remainingCostPerAsset[asset] = remainingCost - costRemoved;
    }
  }

  double totalRemainingCost = 0;
  double totalCurrentValue = 0;

  // Varlık bazında gerçekleşmemiş kâr/zarar.
  final Map<AssetType, double> unrealizedProfitLossPerAsset = {};

  // Açık pozisyonların toplam maliyeti her zaman hesaplanır (altın fiyatı olmasa da).
  for (final entry in remainingCostPerAsset.entries) {
    totalRemainingCost += entry.value;
  }

  // Altın ve altına endeksli varlıklar için gerçekleşmemiş kâr/zarar.
  if (currentGramPrice != null) {
    for (final entry in remainingGramsPerAsset.entries) {
      final asset = entry.key;
      final grams = entry.value;
      if (grams <= 0) continue;

      final currentValue = grams * currentGramPrice;
      totalCurrentValue += currentValue;

      final remainingCost = remainingCostPerAsset[asset] ?? 0;
      final unrealizedForAsset = currentValue - remainingCost;
      unrealizedProfitLossPerAsset[asset] = unrealizedForAsset;
    }
  }

  // ---------------- Döviz (USD / EUR) için kâr/zarar hesabı ----------------
  // Burada gram eşdeğeri olmayan döviz işlemlerini ayrıca ele alıyoruz.
  final fxAssets = currentFxPricePerUnit.keys.toSet();

  // Varlık bazında pozisyon ve maliyet takibi (döviz birimi cinsinden).
  final Map<AssetType, double> remainingUnitsPerFxAsset = {};
  final Map<AssetType, double> remainingCostPerFxAsset = {};

  // Varlık bazında gerçekleşmiş kâr/zarar (döviz).
  final Map<AssetType, double> realizedProfitLossPerFxAsset = {};

  for (final tx in sorted) {
    final asset = tx.assetType;
    if (!fxAssets.contains(asset)) continue;

    final units = tx.amount;
    if (units == 0) continue;

    final remainingUnits = remainingUnitsPerFxAsset[asset] ?? 0;
    final remainingCost = remainingCostPerFxAsset[asset] ?? 0;

    if (tx.direction == TransactionDirection.buy) {
      remainingUnitsPerFxAsset[asset] = remainingUnits + units;
      remainingCostPerFxAsset[asset] = remainingCost + tx.totalValue;
    } else {
      if (remainingUnits <= 0) {
        continue;
      }

      final sellUnits = units.clamp(0, remainingUnits);
      final avgCostPerUnit =
          remainingUnits > 0 ? (remainingCost / remainingUnits) : 0;
      final costRemoved = sellUnits * avgCostPerUnit;
      final saleProceeds = (tx.totalValue / units) * sellUnits;
      final realizedForThisTx = saleProceeds - costRemoved;

      realizedProfitLoss += realizedForThisTx;
      realizedProfitLossPerFxAsset[asset] =
          (realizedProfitLossPerFxAsset[asset] ?? 0) + realizedForThisTx;

      remainingUnitsPerFxAsset[asset] = remainingUnits - sellUnits;
      remainingCostPerFxAsset[asset] = remainingCost - costRemoved;
    }
  }

  // Döviz pozisyonlarının maliyetini toplam maliyete ekle.
  for (final entry in remainingCostPerFxAsset.entries) {
    totalRemainingCost += entry.value;
  }

  // Güncel kur üzerinden dövizlerin güncel değeri ve gerçekleşmemiş kâr/zararı.
  for (final entry in remainingUnitsPerFxAsset.entries) {
    final asset = entry.key;
    final units = entry.value;
    if (units <= 0) continue;

    final currentPrice = currentFxPricePerUnit[asset];
    if (currentPrice == null) continue;

    final currentValue = units * currentPrice;
    totalCurrentValue += currentValue;

    final remainingCost = remainingCostPerFxAsset[asset] ?? 0;
    final unrealizedForAsset = currentValue - remainingCost;
    unrealizedProfitLossPerAsset[asset] =
        (unrealizedProfitLossPerAsset[asset] ?? 0) + unrealizedForAsset;
  }

  final unrealizedProfitLoss = totalCurrentValue - totalRemainingCost;

  final totalProfitLoss = realizedProfitLoss + unrealizedProfitLoss;

  // Gerçekleşmiş + gerçekleşmemiş kâr/zararı varlık bazında birleştir.
  final Map<AssetType, double> totalProfitLossPerAsset = {};
  final allAssets = {
    ...realizedProfitLossPerAsset.keys,
    ...realizedProfitLossPerFxAsset.keys,
    ...unrealizedProfitLossPerAsset.keys,
  };

  for (final asset in allAssets) {
    final realized =
        (realizedProfitLossPerAsset[asset] ?? 0) +
        (realizedProfitLossPerFxAsset[asset] ?? 0);
    final unrealized = unrealizedProfitLossPerAsset[asset] ?? 0;
    totalProfitLossPerAsset[asset] = realized + unrealized;
  }

  return PortfolioSummary(
    totalCost: totalRemainingCost,
    totalCurrentValue: totalCurrentValue,
    totalProfitLoss: totalProfitLoss,
    realizedProfitLoss: realizedProfitLoss,
    unrealizedProfitLoss: unrealizedProfitLoss,
    profitLossPerAsset: totalProfitLossPerAsset,
  );
});

