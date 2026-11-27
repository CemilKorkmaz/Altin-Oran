import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../../../core/formatting.dart';

class PnlDetailsPage extends ConsumerWidget {
  const PnlDetailsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final transactions = ref.watch(transactionsProvider);

    // Basit yaklaşım: her satış işlemi için, o ana kadar oluşan
    // ortalama maliyete göre kabaca kâr/zarar hesaplayalım.
    final realizedRows = _buildRealizedRows(transactions);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kâr / Zarar Detayı'),
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
                      const Text(
                        'Genel Özet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Toplam kâr / zarar: ₺${formatMoney(summary.totalProfitLoss)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: summary.totalProfitLoss > 0
                              ? Colors.green
                              : (summary.totalProfitLoss < 0
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Satışlardan kâr/zarar: ₺${formatMoney(summary.realizedProfitLoss)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: summary.realizedProfitLoss > 0
                              ? Colors.green
                              : (summary.realizedProfitLoss < 0
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Elde tutulan pozisyon kâr/zararı (güncel fiyata göre): ₺${formatMoney(summary.unrealizedProfitLoss)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: summary.unrealizedProfitLoss > 0
                              ? Colors.green
                              : (summary.unrealizedProfitLoss < 0
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _buildExplanation(summary),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Satışlardan Kâr/Zarar',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (realizedRows.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Henüz kâr/zarar oluşmuş bir satış işlemi yok.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ...realizedRows.map((row) => _RealizedPnlCard(row: row)),
            ],
          ),
        ),
      ),
    );
  }
}

class RealizedPnlRow {
  const RealizedPnlRow({
    required this.assetType,
    required this.dateTime,
    required this.amount,
    required this.avgCostPerUnit,
    required this.sellPricePerUnit,
    required this.profitLoss,
    this.goldPurity,
  });

  final AssetType assetType;
  final DateTime dateTime;
  final double amount;
  final double avgCostPerUnit;
  final double sellPricePerUnit;
  final double profitLoss;
  final GoldPurity? goldPurity;
}

List<RealizedPnlRow> _buildRealizedRows(
  List<InvestmentTransaction> transactions,
) {
  final sorted = [...transactions]
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final List<RealizedPnlRow> rows = [];

  // Ortalama maliyet takibi.
  final Map<AssetType, double> totalAmountPerAsset = {};
  final Map<AssetType, double> totalCostPerAsset = {};

  for (final tx in sorted) {
    final asset = tx.assetType;

    final prevAmount = totalAmountPerAsset[asset] ?? 0;
    final prevCost = totalCostPerAsset[asset] ?? 0;

    if (tx.direction == TransactionDirection.buy) {
      totalAmountPerAsset[asset] = prevAmount + tx.amount;
      totalCostPerAsset[asset] = prevCost + tx.totalValue;
    } else {
      if (prevAmount <= 0) {
        continue;
      }

      final sellAmount = tx.amount.clamp(0, prevAmount).toDouble();
      if (sellAmount == 0) continue;

      final avgCostPerUnit =
          prevAmount > 0 ? (prevCost / prevAmount).toDouble() : 0.0;
      final sellPricePerUnit = tx.unitPrice;

      final costRemoved = sellAmount * avgCostPerUnit;
      final proceeds = sellAmount * sellPricePerUnit;
      final profitLoss = proceeds - costRemoved;

      rows.add(
        RealizedPnlRow(
          assetType: asset,
          dateTime: tx.dateTime,
          amount: sellAmount,
          avgCostPerUnit: avgCostPerUnit,
          sellPricePerUnit: sellPricePerUnit,
          profitLoss: profitLoss,
          goldPurity: tx.goldPurity,
        ),
      );

      totalAmountPerAsset[asset] = prevAmount - sellAmount;
      totalCostPerAsset[asset] = prevCost - costRemoved;
    }
  }

  return rows.reversed.toList();
}

class _RealizedPnlCard extends StatelessWidget {
  const _RealizedPnlCard({required this.row});

  final RealizedPnlRow row;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${row.dateTime.day.toString().padLeft(2, '0')}.${row.dateTime.month.toString().padLeft(2, '0')}.${row.dateTime.year}  '
        '${row.dateTime.hour.toString().padLeft(2, '0')}:${row.dateTime.minute.toString().padLeft(2, '0')}';
    final unitLabel = _assetUnitLabel(row.assetType);
    final assetLabel = _isGoldAssetType(row.assetType) && row.goldPurity != null
        ? '${_assetTypeLabel(row.assetType)} (${_goldPurityLabel(row.goldPurity!)})'
        : _assetTypeLabel(row.assetType);
    final isProfit = row.profitLoss > 0;
    final isLoss = row.profitLoss < 0;
    final color = isProfit
        ? Colors.green
        : (isLoss ? Colors.red : Theme.of(context).colorScheme.primary);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      foregroundColor:
                          Theme.of(context).colorScheme.primary,
                      child: Text(
                        _assetTypeShort(row.assetType),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      assetLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  (row.profitLoss >= 0 ? '₺' : '-₺') +
                      formatMoney(row.profitLoss.abs()),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Miktar: ${row.amount.toStringAsFixed(4)} $unitLabel',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Ortalama maliyet: ₺${formatMoney(row.avgCostPerUnit)}',
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              'Satış fiyatı: ₺${formatMoney(row.sellPricePerUnit)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

String _buildExplanation(PortfolioSummary summary) {
  final total = summary.totalProfitLoss;
  final realized = summary.realizedProfitLoss;
  final unrealized = summary.unrealizedProfitLoss;

  String format(double v) =>
      (v >= 0 ? '₺${formatMoney(v)}' : '-₺${formatMoney(v.abs())}');

  if (total == 0 && realized == 0 && unrealized == 0) {
    return 'Şu anda hesaplanmış bir kâr veya zararın bulunmuyor.';
  }

  final totalPart =
      'Toplam kâr/zararın ${format(total)} seviyesinde.';

  final realizedPart =
      'Bunun ${format(realized)} kısmı yaptığın satış işlemlerinden gelen kâr/zarardır.';

  final unrealizedPart =
      'Kalan ${format(unrealized)} ise elinde tuttuğun varlıkların güncel fiyata göre kâr/zararıdır (henüz satmadığın için).';

  return '$totalPart $realizedPart $unrealizedPart';
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
      return 'Hisse Senedi';
  }
}

String _assetTypeShort(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
      return 'GA';
    case AssetType.ceyrek:
      return 'ÇE';
    case AssetType.yarim:
      return 'YR';
    case AssetType.tam:
      return 'TM';
    case AssetType.cumhuriyet:
      return 'CU';
    case AssetType.bilezik22:
      return 'BZ';
    case AssetType.onsAltin:
      return 'ONS';
    case AssetType.gumus:
      return 'AG';
    case AssetType.platin:
      return 'PT';
    case AssetType.paladyum:
      return 'PD';
    case AssetType.usd:
      return 'USD';
    case AssetType.eur:
      return 'EUR';
    case AssetType.btc:
      return 'BTC';
    case AssetType.eth:
      return 'ETH';
    case AssetType.otherCrypto:
      return 'CR';
    case AssetType.stock:
      return 'HS';
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

