import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/transactions_providers.dart';
import '../domain/investment_transaction.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/domain/gold_price.dart';
import '../../../core/formatting.dart';

class TransactionDetailPage extends ConsumerWidget {
  const TransactionDetailPage({
    super.key,
    required this.transactionId,
  });

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final tx =
        transactions.firstWhere((t) => t.id == transactionId, orElse: () => transactions.first);

    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final goldState = ref.watch(goldPriceProvider);
    final currentGramPrice = goldState.price?.pricePerGram;

    final isGold = _isGoldAssetType(tx.assetType);
    final grams = tx.goldEquivalentGrams;

    double? currentUnitPrice;
    double? currentValue;
    double? pnl;

    if (isGold && currentGramPrice != null && grams > 0) {
      currentValue = grams * currentGramPrice;
      currentUnitPrice = currentValue / tx.amount;
      // Alış işleminde fiyat arttıysa kâr, düştüyse zarar gibi düşün.
      if (tx.direction == TransactionDirection.buy) {
        pnl = currentValue - tx.totalValue;
      } else {
        // Satışta pozisyon kapanmış; burada basitçe satış fiyatını güncel fiyata göre kıyaslayalım.
        final hypothetical = grams * currentGramPrice;
        pnl = tx.totalValue - hypothetical;
      }
    }

    // Tüm işlem geçmişi içinde bu kaydın kaçıncı Alış / Satış olduğunu bul.
    String directionLabel;
    {
      final chronological = [...transactions]
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

      int buyIndex = 0;
      int sellIndex = 0;
      String? numbered;
      for (final t in chronological) {
        final isBuy = t.direction == TransactionDirection.buy;
        final idx = isBuy ? ++buyIndex : ++sellIndex;
        if (t.id == tx.id) {
          numbered = isBuy ? 'Alış $idx' : 'Satış $idx';
          break;
        }
      }

      directionLabel = numbered ??
          (tx.direction == TransactionDirection.buy ? 'Alış' : 'Satış');
    }
    final directionColor =
        tx.direction == TransactionDirection.buy ? Colors.green : Colors.red;

    final assetLabel = _isGoldAssetType(tx.assetType) && tx.goldPurity != null
        ? '${_assetTypeLabel(tx.assetType)} (${_goldPurityLabel(tx.goldPurity!)})'
        : _assetTypeLabel(tx.assetType);

    final unitLabel = _assetUnitLabel(tx.assetType);

    Color pnlColor(double v) {
      if (v > 0) return Colors.green;
      if (v < 0) return Colors.red;
      return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    }

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(assetLabel),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: directionColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              directionLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: directionColor,
                              ),
                            ),
                          ),
                          Text(
                            '₺${formatMoney(tx.totalValue)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _detailRow(context, 'Miktar',
                          '${tx.amount.toStringAsFixed(4)} $unitLabel'),
                      if (isGold && grams > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Gram karşılığı: ${grams.toStringAsFixed(4)} gr',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      _detailRow(context, 'Birim fiyat',
                          '₺${formatMoney(tx.unitPrice)}'),
                      const SizedBox(height: 4),
                      _detailRow(context, 'Toplam tutar',
                          '₺${formatMoney(tx.totalValue)}'),
                      const Divider(height: 24),
                      _detailRow(context, 'Tarih / saat',
                          dateFormatter.format(tx.dateTime)),
                      const SizedBox(height: 4),
                      _detailRow(context, 'Kanal',
                          _purchaseChannelLabel(tx.purchaseChannel)),
                      const SizedBox(height: 4),
                      _detailRow(
                        context,
                        'Fiyat girişi',
                        tx.isManualPrice
                            ? 'Manuel'
                            : _priceSourceLabel(tx.priceSource, tx.isManualPrice),
                      ),
                      if (tx.note != null &&
                          tx.note!.trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Not',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tx.note!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (currentGramPrice != null && pnl != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Anlık durum (altın fiyatına göre)',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _detailRow(
                          context,
                          'Güncel gram altın fiyatı',
                          '₺${formatMoney(currentGramPrice)} / gr',
                        ),
                        const SizedBox(height: 4),
                        if (currentUnitPrice != null)
                          _detailRow(
                            context,
                            'Bu işlem için güncel birim fiyat (tahmini)',
                            '₺${formatMoney(currentUnitPrice)}',
                          ),
                        if (currentValue != null) ...[
                          const SizedBox(height: 4),
                          _detailRow(
                            context,
                            'Bu işlem için anlık değer',
                            '₺${formatMoney(currentValue)}',
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Bu işlem için anlık kâr / zarar',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.8),
                                  ),
                            ),
                            Text(
                              '₺${formatMoney(pnl)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: pnlColor(pnl),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.8),
                ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

bool _isGoldAssetType(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
      return true;
    default:
      return false;
  }
}

String _assetTypeLabel(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
      return 'Gram Altın';
    case AssetType.ceyrek:
      return 'Çeyrek Altın';
    case AssetType.yarim:
      return 'Yarım Altın';
    case AssetType.tam:
      return 'Tam Altın';
    case AssetType.cumhuriyet:
      return 'Cumhuriyet Altını';
    case AssetType.bilezik22:
      return '22 Ayar Bilezik';
    case AssetType.onsAltin:
      return 'Ons Altın';
    case AssetType.gumus:
      return 'Gümüş';
    case AssetType.platin:
      return 'Platin';
    case AssetType.paladyum:
      return 'Paladyum';
    case AssetType.usd:
      return 'Dolar (USD)';
    case AssetType.eur:
      return 'Euro (EUR)';
    case AssetType.btc:
      return 'Bitcoin (BTC)';
    case AssetType.eth:
      return 'Ethereum (ETH)';
    case AssetType.otherCrypto:
      return 'Diğer Kripto';
    case AssetType.stock:
      return 'Hisse Senedi / Fon';
  }
}

String _assetUnitLabel(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
    case AssetType.gumus:
    case AssetType.platin:
    case AssetType.paladyum:
      return 'gr';
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.stock:
      return 'adet';
    case AssetType.usd:
      return 'USD';
    case AssetType.eur:
      return 'EUR';
    case AssetType.btc:
      return 'BTC';
    case AssetType.eth:
      return 'ETH';
    case AssetType.otherCrypto:
      return 'token';
  }
}

String _goldPurityLabel(GoldPurity purity) {
  switch (purity) {
    case GoldPurity.carat24:
      return '24 Ayar';
    case GoldPurity.carat22:
      return '22 Ayar';
    case GoldPurity.carat18:
      return '18 Ayar';
    case GoldPurity.carat14:
      return '14 Ayar';
  }
}

String _purchaseChannelLabel(PurchaseChannel channel) {
  switch (channel) {
    case PurchaseChannel.kuyumcuMagaza:
      return 'Kuyumcu (mağaza)';
    case PurchaseChannel.kuyumcuOnline:
      return 'Kuyumcu (online)';
    case PurchaseChannel.bankaSube:
      return 'Banka şubesi';
    case PurchaseChannel.bankaMobil:
      return 'Banka mobil / internet';
    case PurchaseChannel.dovizBurosu:
      return 'Döviz bürosu';
    case PurchaseChannel.borsaViop:
      return 'Borsa / VİOP';
    case PurchaseChannel.onlineAltinPlatformu:
      return 'Online altın platformu';
    case PurchaseChannel.kriptoBorsasi:
      return 'Kripto borsası';
    case PurchaseChannel.aileArkadas:
      return 'Aile / arkadaş';
    case PurchaseChannel.isverenPrimIkramiye:
      return 'İşveren (prim / ikramiye)';
    case PurchaseChannel.diger:
      return 'Diğer';
  }
}

String _priceSourceLabel(PriceSource? source, bool isManual) {
  if (isManual || source == null) {
    return 'Manuel fiyat';
  }
  switch (source) {
    case PriceSource.kapalicarsi:
      return 'Kapalıçarşı';
    case PriceSource.bankalar:
      return 'Bankalar';
    case PriceSource.kitco:
      return 'Kitco';
    case PriceSource.comex:
      return 'COMEX';
    case PriceSource.bloomberg:
      return 'Bloomberg';
  }
  // Tüm durumlar yukarıda ele alındı.
}
