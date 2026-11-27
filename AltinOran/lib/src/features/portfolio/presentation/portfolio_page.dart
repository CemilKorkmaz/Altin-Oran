import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../prices/domain/gold_price.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../rates/presentation/rates_page.dart';
import '../../alerts/application/notification_service.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/presentation/alarm_notification_banner.dart';
import '../../goals/application/goals_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/currency_display.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/application/eur_try_rate_providers.dart';
import '../../../core/formatting.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../../transactions/presentation/add_transaction_page.dart';
import '../../transactions/presentation/transaction_detail_page.dart';
import '../../dashboard/presentation/pnl_details_page.dart';

final portfolioSearchQueryProvider = StateProvider<String>((ref) => '');

class PortfolioPage extends ConsumerWidget {
  const PortfolioPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    final usdRateState = ref.watch(usdTryRateProvider);
    final eurRateState = ref.watch(eurTryRateProvider);
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final goldState = ref.watch(goldPriceProvider);
    final gramTry = goldPricePerGramInTry(goldState.price, usdRateState.rate);
    final allRates = ref.watch(ratesListProvider);
    final alarmsNotifier = ref.watch(priceAlarmsProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      if (!settings.alarmBannerEnabled) return;
      alarmsNotifier.checkAndTrigger(allRates, (alarm, rate) {
        if (!context.mounted || rate.lastPrice == null) return;
        final goals = ref.read(goalsProvider);
        final goal = alarm.goalId != null ? goals.where((g) => g.id == alarm.goalId).firstOrNull : null;
        AlarmNotificationBanner.show(
          context,
          alarm: alarm,
          rate: rate,
          goalTitle: goal?.title,
          onRemoveAlarm: () => ref.read(priceAlarmsProvider.notifier).removeAlarm(alarm.id),
        );
        NotificationService.showAlarmNotification(alarm: alarm, rate: rate, goalTitle: goal?.title);
      });
    });

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          title: const Text('Birikimlerim'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const TransactionsHistoryPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.history_rounded, size: 20),
                label: const Text(
                  'İşlem Geçmişi',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        body: Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, transactions.isEmpty ? 16 : 76),
          child: transactions.isEmpty
              ? _EmptyPortfolioView(
                  onAdd: () {
                    final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionPage(presetGoldPurity: defaultPurity),
                      ),
                    );
                  },
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PnlDetailsPage(),
                          ),
                        );
                      },
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(
                                icon: Icons.pie_chart_rounded,
                                title: 'Genel Özet',
                                subtitle: 'Açık pozisyon ve kâr/zarar',
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Açık pozisyon maliyeti: ${formatDisplayCurrency(summary.totalCost, displayCurrency, usdRateState.rate, eurRateState.rate)}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (displayCurrency != DisplayCurrency.tl)
                                Text(
                                  '≈ ₺${formatMoney(summary.totalCost)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Toplam kâr / zarar: ${summary.totalProfitLoss >= 0 ? '' : '-'}${formatDisplayCurrency(summary.totalProfitLoss.abs(), displayCurrency, usdRateState.rate, eurRateState.rate)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: summary.totalProfitLoss > 0
                                      ? const Color(0xFF42866B)
                                      : (summary.totalProfitLoss < 0
                                          ? const Color(0xFFB75F59)
                                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                ),
                              ),
                              if (displayCurrency != DisplayCurrency.tl)
                                Text(
                                  '≈ ₺${formatMoney(summary.totalProfitLoss.abs())}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: summary.totalProfitLoss > 0
                                        ? const Color(0xFF42866B)
                                        : (summary.totalProfitLoss < 0
                                            ? const Color(0xFFB75F59)
                                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const SectionHeader(
                      icon: Icons.account_balance_wallet_rounded,
                      title: 'Mevcut Varlıklar',
                      subtitle: 'Birikimlerin listesi',
                    ),
                    if (gramTry != null) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Güncel gram altın fiyatı: ₺${formatMoney(gramTry!)} / gr',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (value) => ref
                          .read(portfolioSearchQueryProvider.notifier)
                          .state = value,
                      decoration: InputDecoration(
                        hintText: 'Varlık ara (örn. Gram Altın, USD)',
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _HoldingsList(transactions: transactions),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class TransactionsHistoryPage extends ConsumerWidget {
  const TransactionsHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İşlem Geçmişi'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: transactions.isEmpty
              ? _EmptyPortfolioView(
                  onAdd: () {
                    final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AddTransactionPage(presetGoldPurity: defaultPurity),
                      ),
                    );
                  },
                )
              : _TransactionHistoryList(transactions: transactions),
        ),
      ),
    );
  }
}

/// Gün başlıklarıyla (Bugün, Dün, 6 Mart 2026) gruplanmış işlem listesi.
String _dayHeaderLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final dDate = DateTime(d.year, d.month, d.day);
  final diff = today.difference(dDate).inDays;
  if (diff == 0) return 'Bugün';
  if (diff == 1) return 'Dün';
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

class _TransactionHistoryList extends ConsumerWidget {
  _TransactionHistoryList({required this.transactions});

  final List<InvestmentTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final usdRate = ref.watch(usdTryRateProvider).rate;
    final eurRate = ref.watch(eurTryRateProvider).rate;

    final grouped = <DateTime, List<InvestmentTransaction>>{};
    for (final tx in transactions) {
      final day = DateTime(tx.dateTime.year, tx.dateTime.month, tx.dateTime.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }
    final sortedDays = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final children = <Widget>[];
    for (final day in sortedDays) {
      final dayTxs = grouped[day]!;
      dayTxs.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            _dayHeaderLabel(day),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
      for (final tx in dayTxs) {
        children.add(_transactionHistoryCard(
          context, ref, tx, dateFormatter, displayCurrency, usdRate, eurRate,
        ));
        children.add(const SizedBox(height: 8));
      }
    }
    if (children.isNotEmpty) children.removeLast();

    return ListView(
      padding: const EdgeInsets.only(bottom: 0),
      children: children,
    );
  }

  Widget _transactionHistoryCard(
    BuildContext context,
    WidgetRef ref,
    InvestmentTransaction tx,
    DateFormat dateFormatter,
    DisplayCurrency displayCurrency,
    double? usdRate,
    double? eurRate,
  ) {
    final isBuy = tx.direction == TransactionDirection.buy;
    final dateTimeLabel = dateFormatter.format(tx.dateTime);
    final directionColor = isBuy ? const Color(0xFF42866B) : const Color(0xFFB75F59);
    final directionLabel = isBuy ? 'Alış' : 'Satış';
    final sourceLabel = _priceSourceLabel(tx.priceSource, tx.isManualPrice);
    final sourceIcon = _priceSourceIcon(tx.priceSource, tx.isManualPrice);

    return Card(
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TransactionDetailPage(transactionId: tx.id),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: _holdingAvatarColor(tx.assetType, tx.customAssetId),
          foregroundColor: Colors.white,
          child: Text(_assetTypeShort(tx.assetType), style: const TextStyle(fontSize: 12)),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              tx.goldPurity != null
                  ? '${_assetTypeLabel(tx.assetType)} (${_goldPurityLabel(tx.goldPurity!)})'
                  : _assetTypeLabel(tx.assetType),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: directionColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                directionLabel,
                style: TextStyle(fontSize: 12, color: directionColor, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text('Tarih / saat: $dateTimeLabel'),
            Text('Miktar: ${tx.amount}'),
            Text('Birim fiyat: ${formatDisplayCurrency(tx.unitPrice, displayCurrency, usdRate, eurRate)}'),
            Text('Toplam tutar: ${formatDisplayCurrency(tx.totalValue, displayCurrency, usdRate, eurRate)}'),
            Row(
              children: [
                Icon(sourceIcon, size: 16, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(sourceLabel, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
            Text('Kanal: ${_purchaseChannelLabel(tx.purchaseChannel)}'),
            if (tx.note != null && tx.note!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(tx.note!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
              ),
          ],
        ),
        trailing: PopupMenuButton<_PortfolioAction>(
          onSelected: (action) {
            switch (action) {
              case _PortfolioAction.edit:
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddTransactionPage(existing: tx)),
                );
                break;
              case _PortfolioAction.sell:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddTransactionPage(
                      presetAssetType: tx.assetType,
                      presetChannel: tx.purchaseChannel,
                      presetDirection: TransactionDirection.sell,
                      presetGoldPurity: tx.goldPurity,
                      presetCustomAssetId: tx.customAssetId,
                      titleOverride: 'Satış Yap',
                    ),
                  ),
                );
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: _PortfolioAction.edit, child: Text('Düzenle')),
            PopupMenuItem(value: _PortfolioAction.sell, child: Text('Satış yap')),
          ],
        ),
      ),
    );
  }
}

class _HoldingsList extends ConsumerWidget {
  const _HoldingsList({required this.transactions});

  final List<InvestmentTransaction> transactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final query = ref.watch(portfolioSearchQueryProvider).trim().toLowerCase();
    if (transactions.isEmpty) {
      return _EmptyPortfolioView(
        onAdd: () {
          final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTransactionPage(presetGoldPurity: defaultPurity),
            ),
          );
        },
      );
    }

    final Map<_HoldingKey, double> amountsPerKey = {};

    for (final tx in transactions) {
      final key = _HoldingKey(tx.assetType, tx.goldPurity, tx.customAssetId);
      final sign = tx.direction == TransactionDirection.buy ? 1.0 : -1.0;
      final current = amountsPerKey[key] ?? 0;
      final next = current + sign * tx.amount;
      amountsPerKey[key] = next > 0 ? next : 0;
    }

    final entries = amountsPerKey.entries
        .where((e) => e.value > 0)
        .where((e) {
          if (query.isEmpty) return true;
          final title = _holdingTitle(
            ref,
            e.key.assetType,
            e.key.goldPurity,
            e.key.customAssetId,
          ).toLowerCase();
          final code = _assetTypeShort(e.key.assetType).toLowerCase();
          return title.contains(query) || code.contains(query);
        })
        .toList()
      ..sort((a, b) {
        final profitA = summary.profitLossPerAsset[a.key.assetType] ?? 0.0;
        final profitB = summary.profitLossPerAsset[b.key.assetType] ?? 0.0;
        final byProfit = profitB.compareTo(profitA);
        if (byProfit != 0) return byProfit;
        final titleA = _holdingTitle(ref, a.key.assetType, a.key.goldPurity, a.key.customAssetId);
        final titleB = _holdingTitle(ref, b.key.assetType, b.key.goldPurity, b.key.customAssetId);
        return titleA.compareTo(titleB);
      });

    if (entries.isEmpty) {
      return _EmptyPortfolioView(
        onAdd: () {
          final defaultPurity = ref.read(appSettingsProvider).defaultGramPurity;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddTransactionPage(presetGoldPurity: defaultPurity),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 0),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final key = entry.key;
        final asset = key.assetType;
        final purity = key.goldPurity;
        final amount = entry.value;
        final unitLabel = _assetUnitLabel(asset);
        final assetProfitLoss =
            summary.profitLossPerAsset[asset] ?? 0.0;

        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final sellColor = theme.colorScheme.error;
        final sellBg = isDark ? sellColor.withOpacity(0.15) : sellColor.withOpacity(0.08);
        Widget trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (assetProfitLoss != 0) ...[
              Text(
                '${assetProfitLoss > 0 ? '+' : ''}₺${formatMoney(assetProfitLoss.abs())}',
                style: TextStyle(
                  color: assetProfitLoss > 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionPage(
                        presetAssetType: asset,
                        presetDirection: TransactionDirection.sell,
                        presetGoldPurity: purity,
                        presetCustomAssetId: key.customAssetId,
                        titleOverride: 'Satış – ${_holdingTitle(ref, asset, purity, key.customAssetId)}',
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sellColor.withOpacity(0.8), width: 1.2),
                    color: sellBg,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sell_rounded, size: 18, color: sellColor),
                      const SizedBox(width: 6),
                      Text(
                        'Sat',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: sellColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

        return Card(
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AssetDetailPage(
                    assetType: asset,
                    goldPurity: purity,
                    customAssetId: key.customAssetId,
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: _holdingAvatarColor(asset, key.customAssetId),
              foregroundColor: Colors.white,
              child: Text(
                _assetTypeShort(asset),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            title: Text(
              _holdingTitle(ref, asset, purity, key.customAssetId),
            ),
            subtitle: Text('Miktar: ${amount.toStringAsFixed(2)} $unitLabel'),
            trailing: trailing,
          ),
        );
      },
    );
  }
}

class _EmptyPortfolioView extends StatelessWidget {
  const _EmptyPortfolioView({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Henüz portföyünde kayıtlı varlık yok',
      description: 'Altın, döviz ve diğer varlıklarınızı ekleyerek birikiminizi takip etmeye başlayın.',
      actionLabel: 'Yatırım Ekle',
      onAction: onAdd,
    );
  }
}

/// Tek bir varlığa özel detay: özet (maliyet, kâr/zarar) + alış/satış tarihçesi.
class AssetDetailPage extends ConsumerWidget {
  const AssetDetailPage({
    super.key,
    required this.assetType,
    this.goldPurity,
    this.customAssetId,
  });

  final AssetType assetType;
  final GoldPurity? goldPurity;
  final String? customAssetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final goldState = ref.watch(goldPriceProvider);
    final usdRateState = ref.watch(usdTryRateProvider);
    final dateFormatter = DateFormat('dd.MM.yyyy HH:mm');

    final filtered = transactions
        .where((tx) =>
            tx.assetType == assetType &&
            (goldPurity == null || tx.goldPurity == goldPurity) &&
            (customAssetId == null || tx.customAssetId == customAssetId))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Global işlem geçmişine göre Alış / Satış numaralarını hazırla.
    final Map<String, String> globalDirectionLabels = () {
      final chronological = [...transactions]
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      int buyIndex = 0;
      int sellIndex = 0;
      final map = <String, String>{};
      for (final tx in chronological) {
        final isBuy = tx.direction == TransactionDirection.buy;
        final idx = isBuy ? ++buyIndex : ++sellIndex;
        map[tx.id] = isBuy ? 'Alış $idx' : 'Satış $idx';
      }
      return map;
    }();

    final isGoldType = _isGoldAssetType(assetType);
    double remainingGrams = 0;
    double remainingCost = 0;
    double realizedPnL = 0;

    if (isGoldType) {
      final chronological = [...filtered]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      for (final tx in chronological) {
        final grams = tx.goldEquivalentGrams;
        if (grams == 0) continue;
        if (tx.direction == TransactionDirection.buy) {
          remainingGrams += grams;
          remainingCost += tx.totalValue;
        } else {
          if (remainingGrams <= 0) continue;
          final sellGrams = grams.clamp(0, remainingGrams);
          final avgCostPerGram = remainingGrams > 0 ? (remainingCost / remainingGrams) : 0;
          final costRemoved = sellGrams * avgCostPerGram;
          final saleProceeds = (tx.totalValue / grams) * sellGrams;
          realizedPnL += saleProceeds - costRemoved;
          remainingGrams -= sellGrams;
          remainingCost -= costRemoved;
        }
      }
    } else {
      final chronological = [...filtered]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      for (final tx in chronological) {
        final amt = tx.amount;
        if (tx.direction == TransactionDirection.buy) {
          remainingGrams += amt;
          remainingCost += tx.totalValue;
        } else {
          if (remainingGrams <= 0) continue;
          final sellAmt = amt.clamp(0, remainingGrams);
          final avgCostPerUnit = remainingGrams > 0 ? (remainingCost / remainingGrams) : 0;
          final costRemoved = sellAmt * avgCostPerUnit;
          final saleProceeds = (tx.totalValue / amt) * sellAmt;
          realizedPnL += saleProceeds - costRemoved;
          remainingGrams -= sellAmt;
          remainingCost -= costRemoved;
        }
      }
    }

    final currentGramPrice = goldPricePerGramInTry(goldState.price, usdRateState.rate);
    final currentValue = isGoldType && currentGramPrice != null && currentGramPrice > 0
        ? remainingGrams * currentGramPrice
        : remainingCost;
    final unrealizedPnL = isGoldType && currentGramPrice != null
        ? (currentValue - remainingCost)
        : 0.0;
    final totalPnL = realizedPnL + unrealizedPnL;

    final title = customAssetId != null
        ? (() {
            try {
              return ref
                  .watch(allSupportedAssetsProvider)
                  .firstWhere((x) => x.id == customAssetId)
                  .name;
            } catch (_) {
              return _assetTypeLabel(assetType);
            }
          }())
        : (_isGoldAssetType(assetType) && goldPurity != null
            ? '${_assetTypeLabel(assetType)} (${_goldPurityLabel(goldPurity!)})'
            : _assetTypeLabel(assetType));
    final unitLabel = _assetUnitLabel(assetType);

    // Adet bazlı altınlarda (çeyrek, yarım, tam, cumhuriyet) miktarı adet göster; gram karşılığını ayrı satırda yaz.
    final gramsPerUnit = _gramsPerUnitForGoldCoin(assetType);
    final String miktarText;
    if (unitLabel == 'adet' && gramsPerUnit != null && gramsPerUnit > 0) {
      final remainingPieces = remainingGrams / gramsPerUnit;
      miktarText = '${remainingPieces.toStringAsFixed(2)} adet';
    } else {
      miktarText = '${remainingGrams.toStringAsFixed(2)} $unitLabel';
    }

    final showSellButton = filtered.isNotEmpty && remainingGrams > 0;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: filtered.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Bu varlık için henüz işlem kaydı yok.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      children: [
                        Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Özet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isGoldType && currentGramPrice != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Güncel gram altın fiyatı: ₺${formatMoney(currentGramPrice!)} / gr',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          _detailRow(context, 'Miktar', miktarText),
                          if (isGoldType && remainingGrams > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Gram karşılığı: ${remainingGrams.toStringAsFixed(2)} gr',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          _detailRow(context, 'Açık pozisyon maliyeti', '₺${formatMoney(remainingCost)}'),
                          if (usdRateState.rate != null && usdRateState.rate! > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 0, top: 2),
                              child: Text(
                                '≈ \$${(remainingCost / usdRateState.rate!).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),
                          _detailRow(context, 'Güncel değer (tahmini)', '₺${formatMoney(currentValue)}'),
                          const SizedBox(height: 8),
                          Text(
                            'Kâr / Zarar: ₺${totalPnL >= 0 ? '' : '-'}${formatMoney(totalPnL.abs())}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: totalPnL > 0 ? const Color(0xFF42866B) : (totalPnL < 0 ? const Color(0xFFB75F59) : Theme.of(context).colorScheme.onSurface),
                            ),
                          ),
                          if (usdRateState.rate != null && usdRateState.rate! > 0)
                            Text(
                              '≈ \$${(totalPnL / usdRateState.rate!).toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: totalPnL > 0 ? const Color(0xFF42866B) : (totalPnL < 0 ? const Color(0xFFB75F59) : Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Satışlardan kâr/zarar: ₺${formatMoney(realizedPnL)}  ·  Elde tutulan pozisyon kâr/zararı: ₺${formatMoney(unrealizedPnL)}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'İşlem tarihçesi',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Her alış / satış işlemini global işlem geçmişine göre numaralandır (Alış 1, Satış 1, ...).
                  ...filtered.map((tx) {
                    final isBuy = tx.direction == TransactionDirection.buy;
                    final directionColor =
                        isBuy ? const Color(0xFF42866B) : const Color(0xFFB75F59);
                    final directionLabel =
                        globalDirectionLabels[tx.id] ?? (isBuy ? 'Alış' : 'Satış');
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TransactionDetailPage(
                                  transactionId: tx.id,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: directionColor
                                            .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        directionLabel,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: directionColor,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '₺${formatMoney(tx.totalValue)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${tx.amount.toStringAsFixed(2)} $unitLabel × ₺${formatMoney(tx.unitPrice)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateFormatter.format(tx.dateTime),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.7),
                                      ),
                                ),
                                if (tx.note != null &&
                                    tx.note!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    tx.note!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                      ],
                    ),
                  ),
                  if (showSellButton)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: Center(
                        child: _AssetDetailSellButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AddTransactionPage(
                                  presetAssetType: assetType,
                                  presetDirection: TransactionDirection.sell,
                                  presetGoldPurity: goldPurity,
                                  presetCustomAssetId: customAssetId,
                                  titleOverride: 'Satış – $title',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static Widget _detailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Varlık detay sayfasında alt ortada gösterilen satış butonu.
class _AssetDetailSellButton extends StatelessWidget {
  const _AssetDetailSellButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sellColor = theme.colorScheme.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: sellColor.withOpacity(0.12),
            border: Border.all(color: sellColor.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: sellColor.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sell_rounded, size: 22, color: sellColor),
              const SizedBox(width: 10),
              Text(
                'Sat',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: sellColor,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PortfolioAction { edit, sell }

class _HoldingKey {
  const _HoldingKey(this.assetType, this.goldPurity, [this.customAssetId]);

  final AssetType assetType;
  final GoldPurity? goldPurity;
  final String? customAssetId;

  @override
  bool operator ==(Object other) {
    return other is _HoldingKey &&
        other.assetType == assetType &&
        other.goldPurity == goldPurity &&
        other.customAssetId == customAssetId;
  }

  @override
  int get hashCode => Object.hash(assetType, goldPurity, customAssetId);
}

String _holdingTitle(
    WidgetRef ref, AssetType asset, GoldPurity? purity, String? customAssetId) {
  if (customAssetId != null) {
    final all = ref.watch(allSupportedAssetsProvider);
    try {
      return all.firstWhere((x) => x.id == customAssetId).name;
    } catch (_) {}
  }
  // Gram altın / ayarlı altınlarda mutlaka ayar göster (yoksa 24 kabul et)
  if (_isGoldAssetType(asset)) {
    final p = purity ?? GoldPurity.carat24;
    return '${_assetTypeLabel(asset)} (${_goldPurityLabel(p)})';
  }
  return _assetTypeLabel(asset);
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

/// Kurlar sayfasındaki varlık renkleriyle aynı (Au altın sarısı, Ag gümüş grisi, vb.).
Color _holdingAvatarColor(AssetType type, [String? customAssetId]) {
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
      return const Color(0xFFD4AF37); // Au altın
    case AssetType.gumus:
      return const Color(0xFFA8A9AD); // Ag gümüş
    case AssetType.platin:
      return const Color(0xFFE5E4E2); // Pt platin
    case AssetType.paladyum:
      return const Color(0xFFB4B4B4); // Pd paladyum
    case AssetType.usd:
      return const Color(0xFF2E7D32); // dolar yeşil
    case AssetType.eur:
      return const Color(0xFF1565C0); // euro mavi
    case AssetType.btc:
      return const Color(0xFFF7931A);
    case AssetType.eth:
      return const Color(0xFF627EEA);
    case AssetType.otherCrypto:
      return const Color(0xFF22C55E); // diğer kripto
    case AssetType.stock:
      return const Color(0xFF6B7280);
  }
}

/// Kurlar sayfasındaki sembollerle aynı (Au, Ag, Pt, Pd, USD, EUR, BTC, ETH).
String _assetTypeShort(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
      return 'Au';
    case AssetType.gumus:
      return 'Ag';
    case AssetType.platin:
      return 'Pt';
    case AssetType.paladyum:
      return 'Pd';
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

/// Adet bazlı altınlarda 1 adet = kaç gram (çeyrek 1.75, yarım 3.5, tam 7, cumhuriyet 7.216).
/// Diğer varlıklar için null.
double? _gramsPerUnitForGoldCoin(AssetType type) {
  switch (type) {
    case AssetType.ceyrek:
      return 1.75;
    case AssetType.yarim:
      return 3.5;
    case AssetType.tam:
      return 7.0;
    case AssetType.cumhuriyet:
      return 7.216;
    default:
      return null;
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
}

IconData _priceSourceIcon(PriceSource? source, bool isManual) {
  if (isManual || source == null) {
    return Icons.edit_rounded;
  }
  switch (source) {
    case PriceSource.kapalicarsi:
      return Icons.storefront_rounded;
    case PriceSource.bankalar:
      return Icons.account_balance_rounded;
    case PriceSource.kitco:
      return Icons.public_rounded;
    case PriceSource.comex:
      return Icons.show_chart_rounded;
    case PriceSource.bloomberg:
      return Icons.assessment_rounded;
  }
}

