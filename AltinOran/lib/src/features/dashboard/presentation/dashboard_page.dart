import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/section_header.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import 'pnl_details_page.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/live_asset_price_provider.dart';
import '../../prices/domain/gold_price.dart';
import '../../prices/domain/supported_asset.dart';
import '../../prices/presentation/select_asset_for_live_page.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/application/eur_try_rate_providers.dart';
import '../../../core/formatting.dart';
import '../../rates/presentation/rates_page.dart';
import '../../alerts/application/notification_service.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/presentation/alarm_notification_banner.dart';
import '../../goals/application/goals_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/currency_display.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(portfolioSummaryProvider);
    final goldState = ref.watch(goldPriceProvider);
    final selectedRegion = ref.watch(selectedRegionProvider);
    final usdRateState = ref.watch(usdTryRateProvider);
    final eurRateState = ref.watch(eurTryRateProvider);
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final allRates = ref.watch(ratesListProvider);
    final alarmsNotifier = ref.watch(priceAlarmsProvider.notifier);

    // Günlük değişim (portföyü yaklaşık olarak altın fiyat hareketine göre ölçekler).
    String todayText = 'Bugün: —';
    if (goldState.price != null &&
        goldState.previousPrice != null &&
        summary.totalCost > 0) {
      final current = goldState.price!.pricePerGram;
      final previous = goldState.previousPrice!.pricePerGram;
      if (previous > 0) {
        final pctChange = ((current - previous) / previous) * 100;
        final dayPnl = summary.totalCost * pctChange / 100;
        final sign = dayPnl >= 0 ? '' : '-';
        final absPnl = dayPnl.abs();
        final pctText = pctChange >= 0
            ? pctChange.toStringAsFixed(2)
            : (-pctChange).toStringAsFixed(2);
        final formattedPnl = formatDisplayCurrency(
          absPnl, displayCurrency, usdRateState.rate, eurRateState.rate,
        );
        todayText = 'Bugün: $sign$formattedPnl ($sign$pctText%)';
      }
    }

    // Ana sayfa açıldığında Bigpara verisini bir kez tetikle (Kurlar ile aynı throttle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastAt = ref.read(lastRatesRefreshAtProvider);
      final now = DateTime.now();
      if (lastAt == null || now.difference(lastAt).inSeconds > 60) {
        ref.read(lastRatesRefreshAtProvider.notifier).state = now;
        ref.read(bigparaByKeyProvider.notifier).refresh();
      }
    });

    // Fiyat alarmlarını burada da dinle ki kullanıcı hangi sayfada olursa olsun
    // üstten gelen bildirim banner'ını görebilsin.
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
          title: const Text('Birikim & Portföy'),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.read(lastRatesRefreshAtProvider.notifier).state = DateTime.now();
            await ref.read(bigparaByKeyProvider.notifier).refresh();
            ref.read(usdTryRateProvider.notifier).refresh();
            ref.read(eurTryRateProvider.notifier).refresh();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ListView(
              children: [
                _DashboardAdBanner(),
                const SizedBox(height: 8),
                const SectionHeader(
                  icon: Icons.pie_chart_rounded,
                  title: 'Genel Özet',
                  subtitle: 'Portföy kâr/zarar özeti',
                ),
                const SizedBox(height: 4),
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PnlDetailsPage(),
                      ),
                    );
                  },
                  child: ProfitLossRing(
                    profitLoss: summary.totalProfitLoss,
                    totalCost: summary.totalCost,
                    formattedAmount: summary.totalProfitLoss >= 0
                        ? formatDisplayCurrency(
                            summary.totalProfitLoss,
                            displayCurrency,
                            usdRateState.rate,
                            eurRateState.rate,
                          )
                        : '-${formatDisplayCurrency(
                            -summary.totalProfitLoss,
                            displayCurrency,
                            usdRateState.rate,
                            eurRateState.rate,
                          )}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GoldPriceCard(
                state: goldState,
                region: selectedRegion,
                onRegionChanged: (region) =>
                    ref.read(selectedRegionProvider.notifier).state = region,
                onRefresh: () async {
                  ref.read(lastRatesRefreshAtProvider.notifier).state = DateTime.now();
                  await ref.read(bigparaByKeyProvider.notifier).refresh();
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam Birikim Değeri',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // TL toplam değer
                      Text(
                        formatDisplayCurrency(
                          summary.totalCurrentValue > 0 ? summary.totalCurrentValue : summary.totalCost,
                          displayCurrency,
                          usdRateState.rate,
                          eurRateState.rate,
                        ),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // İkincil para birimi (TL seçiliyse ≈ USD, aksi halde ≈ ₺)
                      if (displayCurrency == DisplayCurrency.tl &&
                          usdRateState.rate != null &&
                          usdRateState.rate! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '≈ \$${formatMoney((summary.totalCurrentValue > 0 ? summary.totalCurrentValue : summary.totalCost) / usdRateState.rate!)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ]
                      else if ((displayCurrency == DisplayCurrency.usd || displayCurrency == DisplayCurrency.eur) &&
                          usdRateState.rate != null &&
                          usdRateState.rate! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '≈ ₺${formatMoney(summary.totalCurrentValue > 0 ? summary.totalCurrentValue : summary.totalCost)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        todayText,
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
                'Portföy Dağılımı',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const SectionHeader(
                icon: Icons.stacked_bar_chart_rounded,
                title: 'Portföy Dağılımı',
                subtitle: 'Maden, döviz ve coin dağılımı',
              ),
              const SizedBox(height: 4),
              const PortfolioDistributionCard(),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class ProfitLossRing extends StatelessWidget {
  const ProfitLossRing({
    super.key,
    required this.profitLoss,
    required this.totalCost,
    this.formattedAmount,
  });

  /// Genel toplam kâr/zarar (TL)
  final double profitLoss;

  /// Halkadaki doluluk oranını ölçeklemek için toplam maliyet.
  final double totalCost;

  /// Görüntü para birimine göre formatlanmış tutar (örn. "₺1.234" veya "$456"). Verilmezse TL kullanılır.
  final String? formattedAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool isProfit = profitLoss > 0;
    final bool isLoss = profitLoss < 0;

    final Color ringColor;
    if (isProfit) {
      ringColor = Colors.green;
    } else if (isLoss) {
      ringColor = Colors.red;
    } else {
      ringColor = theme.colorScheme.primary; // nötr durumda mavi ton
    }

    final String amountText = formattedAmount ??
        (profitLoss >= 0
            ? '₺${formatMoney(profitLoss)}'
            : '-₺${formatMoney(profitLoss.abs())}');

    // Kâr/zararın büyüklüğüne göre halkanın doluluk oranı (0–1).
    double progress = 0;
    if (totalCost > 0) {
      progress = (profitLoss.abs() / totalCost).clamp(0.0, 1.0);
    }

    return SizedBox(
      height: 220,
      width: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 200,
            width: 200,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 14,
              color: ringColor,
              backgroundColor: ringColor.withOpacity(0.22),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Genel Kâr/Zarar',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                amountText,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: ringColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PortfolioDistributionCard extends ConsumerWidget {
  const PortfolioDistributionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final goldState = ref.watch(goldPriceProvider);
    final currentGramPrice = goldState.price?.pricePerGram;
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final usdRate = ref.watch(usdTryRateProvider).rate;
    final eurRate = ref.watch(eurTryRateProvider).rate;

    if (transactions.isEmpty) {
      return Card(
        child: SizedBox(
          height: 180,
          child: Center(
            child: Text(
              'Henüz yatırım eklenmedi.\n\nPortföyün dağılımını görmek için sağ alttan \"Yatırım Ekle\" butonunu kullan.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    final dist = _computeDistributionData(transactions, currentGramPrice, usdTry: usdRate, eurTry: eurRate);

    final goldEntries = dist.goldGrams.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalGoldGrams =
        goldEntries.fold<double>(0, (sum, e) => sum + e.value);

    final fxEntries = dist.fxValues.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalFxValue =
        fxEntries.fold<double>(0, (sum, e) => sum + e.value);

    final riskEntries = dist.riskValues.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final totalRiskValue =
        riskEntries.fold<double>(0, (sum, e) => sum + e.value);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PortfolioDistributionDetailPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Varlık dağılımı',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (goldEntries.isNotEmpty) ...[
                Text(
                  'Maden bazlı varlık dağılımı',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...goldEntries.map((e) {
                  final asset = e.key;
                  final grams = e.value;
                  final ratio =
                      totalGoldGrams > 0 ? grams / totalGoldGrams : 0.0;
                  final percent = ratio * 100;
                  final color = _assetColor(asset);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dashboardAssetLabel(asset),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            Text(
                              '${grams.toStringAsFixed(2)} gr (${percent.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (fxEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Döviz bazlı varlık dağılımı',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...fxEntries.map((e) {
                  final asset = e.key;
                  final value = e.value;
                  final ratio =
                      totalFxValue > 0 ? value / totalFxValue : 0.0;
                  final percent = ratio * 100;
                  final color = _assetColor(asset);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dashboardAssetLabel(asset),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            Text(
                              '${formatDisplayCurrency(value, displayCurrency, usdRate, eurRate)} (${percent.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (riskEntries.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Coin / hisse bazlı varlık dağılımı',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                ...riskEntries.map((e) {
                  final asset = e.key;
                  final value = e.value;
                  final ratio =
                      totalRiskValue > 0 ? value / totalRiskValue : 0.0;
                  final percent = ratio * 100;
                  final color = _assetColor(asset);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _dashboardAssetLabel(asset),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                            Text(
                              '${formatDisplayCurrency(value, displayCurrency, usdRate, eurRate)} (${percent.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: ratio.clamp(0.0, 1.0),
                            minHeight: 6,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (goldEntries.isEmpty &&
                  fxEntries.isEmpty &&
                  riskEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Açık pozisyon bulunmuyor.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _assetColor(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
      return const Color(0xFFB8860B); // koyu altın (tema primary)
    case AssetType.ceyrek:
      return const Color(0xFFF59E0B); // sarı/turuncu
    case AssetType.yarim:
      return const Color(0xFF10B981); // yeşil
    case AssetType.tam:
      return const Color(0xFFEC4899); // pembe
    case AssetType.cumhuriyet:
      return const Color(0xFF8B5CF6); // mor
    case AssetType.bilezik22:
      return const Color(0xFFF97316); // turuncu
    case AssetType.onsAltin:
      return const Color(0xFF0EA5E9); // açık mavi
    default:
      return const Color(0xFF6B7280); // gri
  }
}

class _DistributionData {
  const _DistributionData({
    required this.goldGrams,
    required this.goldValues,
    required this.fxValues,
    required this.riskValues,
  });

  final Map<AssetType, double> goldGrams;
  final Map<AssetType, double> goldValues;
  final Map<AssetType, double> fxValues;
  final Map<AssetType, double> riskValues;

  Map<AssetType, double> get allValues => {
        ...goldValues,
        ...fxValues,
        ...riskValues,
      };

  double get totalValue =>
      allValues.values.fold<double>(0, (sum, v) => sum + v);
}

double _metalGramsForTx(InvestmentTransaction tx) {
  switch (tx.assetType) {
    case AssetType.gramAltin:
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
    case AssetType.bilezik22:
    case AssetType.onsAltin:
      return tx.goldEquivalentGrams;
    case AssetType.gumus:
    case AssetType.platin:
    case AssetType.paladyum:
      return tx.amount;
    default:
      return 0;
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

_DistributionData _computeDistributionData(
  List<InvestmentTransaction> transactions,
  double? currentGramPrice, {
  double? usdTry,
  double? eurTry,
}) {
  // Döviz kurları API'den (TL). Yoksa o varlık dağılıma dahil edilmez.
  final fxPrices = <AssetType, double>{};
  if (usdTry != null) fxPrices[AssetType.usd] = usdTry;
  if (eurTry != null) fxPrices[AssetType.eur] = eurTry;

  const fxAssets = <AssetType>{AssetType.usd, AssetType.eur};
  const riskAssets = <AssetType>{
    AssetType.btc,
    AssetType.eth,
    AssetType.otherCrypto,
    AssetType.stock,
  };

  final sorted = [...transactions]
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final Map<AssetType, double> goldGrams = {};
  final Map<AssetType, double> goldCost = {};

  final Map<AssetType, double> fxUnits = {};
  final Map<AssetType, double> fxCost = {};

  final Map<AssetType, double> riskUnits = {};
  final Map<AssetType, double> riskCost = {};

  for (final tx in sorted) {
    final asset = tx.assetType;
    final isBuy = tx.direction == TransactionDirection.buy;

    final metalGrams = _metalGramsForTx(tx);
    if (metalGrams > 0) {
      final sign = isBuy ? 1.0 : -1.0;
      final gCurrent = goldGrams[asset] ?? 0;
      final cCurrent = goldCost[asset] ?? 0;

      final gNext = gCurrent + sign * metalGrams;
      final cNext = cCurrent + sign * tx.totalValue;

      goldGrams[asset] = gNext > 0 ? gNext : 0;
      goldCost[asset] = cNext > 0 ? cNext : 0;
      continue;
    }

    if (fxAssets.contains(asset)) {
      final units = tx.amount;
      if (units == 0) continue;

      final sign = isBuy ? 1.0 : -1.0;
      final uCurrent = fxUnits[asset] ?? 0;
      final cCurrent = fxCost[asset] ?? 0;

      final uNext = uCurrent + sign * units;
      final cNext = cCurrent + sign * tx.totalValue;

      fxUnits[asset] = uNext > 0 ? uNext : 0;
      fxCost[asset] = cNext > 0 ? cNext : 0;
      continue;
    }

    if (riskAssets.contains(asset)) {
      final units = tx.amount;
      if (units == 0) continue;

      final sign = isBuy ? 1.0 : -1.0;
      final uCurrent = riskUnits[asset] ?? 0;
      final cCurrent = riskCost[asset] ?? 0;

      final uNext = uCurrent + sign * units;
      final cNext = cCurrent + sign * tx.totalValue;

      riskUnits[asset] = uNext > 0 ? uNext : 0;
      riskCost[asset] = cNext > 0 ? cNext : 0;
    }
  }

  final Map<AssetType, double> goldValues = {};
  goldGrams.forEach((asset, grams) {
    if (grams <= 0) return;
    final cost = goldCost[asset] ?? 0;
    double value;
    if (_isGoldAssetType(asset) && currentGramPrice != null) {
      // Altına çevrilebilir varlıklar için güncel gram altın fiyatına göre değer.
      value = grams * currentGramPrice;
    } else {
      // Diğer metaller (gümüş, platin, paladyum) için şimdilik maliyet üzerinden yaklaşık değer.
      value = cost;
    }
    if (value > 0) {
      goldValues[asset] = value;
    }
  });

  final Map<AssetType, double> fxValues = {};
  fxUnits.forEach((asset, units) {
    if (units <= 0) return;
    final price = fxPrices[asset];
    if (price == null) return;
    final value = units * price;
    if (value > 0) {
      fxValues[asset] = value;
    }
  });

  final Map<AssetType, double> riskValues = {};
  riskCost.forEach((asset, cost) {
    if (cost > 0) {
      riskValues[asset] = cost;
    }
  });

  return _DistributionData(
    goldGrams: goldGrams,
    goldValues: goldValues,
    fxValues: fxValues,
    riskValues: riskValues,
  );
}

String _goldPurityLabel(GoldPurity p) {
  switch (p) {
    case GoldPurity.carat24: return '24 Ayar';
    case GoldPurity.carat22: return '22 Ayar';
    case GoldPurity.carat18: return '18 Ayar';
    case GoldPurity.carat14: return '14 Ayar';
  }
}

String _dashboardAssetLabel(AssetType type) {
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

class PortfolioDistributionDetailPage extends ConsumerWidget {
  const PortfolioDistributionDetailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final goldState = ref.watch(goldPriceProvider);
    final currentGramPrice = goldState.price?.pricePerGram;
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final usdRate = ref.watch(usdTryRateProvider).rate;
    final eurRate = ref.watch(eurTryRateProvider).rate;

    if (transactions.isEmpty) {
      return SafeArea(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Varlık dağılımı'),
          ),
          body: const Center(
            child: Text('Henüz yatırım eklenmedi.'),
          ),
        ),
      );
    }

    final dist = _computeDistributionData(transactions, currentGramPrice, usdTry: usdRate, eurTry: eurRate);
    final entries = dist.allValues.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = dist.totalValue;

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Varlık dağılımı'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: entries.isEmpty
              ? const Center(
                  child: Text('Açık pozisyon bulunmuyor.'),
                )
              : ListView.builder(
                  itemCount: entries.length + 1,
                  itemBuilder: (context, index) {
                    if (index == entries.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Toplam portföy değeri: ${formatDisplayCurrency(total, displayCurrency, usdRate, eurRate)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      );
                    }

                    final entry = entries[index];
                    final asset = entry.key;
                    final value = entry.value;
                    final ratio = total > 0 ? value / total : 0.0;
                    final percent = ratio * 100;
                    final color = _assetColor(asset);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _dashboardAssetLabel(asset),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                '${formatDisplayCurrency(value, displayCurrency, usdRate, eurRate)} (${percent.toStringAsFixed(1)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withOpacity(0.2),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DashboardAdBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceVariant.withOpacity(0.9),
        ),
        child: Row(
          children: [
            Icon(
              Icons.campaign_rounded,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reklam alanı – burada işbirliği / sponsor içeriği gösterebilirsin.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color:
                      theme.colorScheme.onSurface.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GoldPriceCard extends ConsumerStatefulWidget {
  const GoldPriceCard({
    super.key,
    required this.state,
    required this.region,
    required this.onRegionChanged,
    required this.onRefresh,
  });

  final GoldPriceState state;
  final PriceRegion region;
  final ValueChanged<PriceRegion> onRegionChanged;
  final VoidCallback onRefresh;

  @override
  ConsumerState<GoldPriceCard> createState() => _GoldPriceCardState();
}

class _GoldPriceCardState extends ConsumerState<GoldPriceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _liveController;

  @override
  void initState() {
    super.initState();
    _liveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _liveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final region = widget.region;
    final onRegionChanged = widget.onRegionChanged;
    final onRefresh = widget.onRefresh;
    final theme = Theme.of(context);
    final selectedId = ref.watch(selectedLiveAssetIdProvider);
    final liveIds = ref.watch(liveSelectedAssetIdsProvider);
    final asset = ref.watch(supportedAssetByIdProvider(selectedId));
    final allAssets = ref.watch(allSupportedAssetsProvider);
    final useTry = region == PriceRegion.turkey;

    IconData trendIcon;
    Color trendColor;
    switch (state.trend) {
      case PriceTrend.up:
        trendIcon = Icons.arrow_upward_rounded;
        trendColor = Colors.green;
        break;
      case PriceTrend.down:
        trendIcon = Icons.arrow_downward_rounded;
        trendColor = Colors.red;
        break;
      case PriceTrend.flat:
        trendIcon = Icons.horizontal_rule_rounded;
        trendColor = theme.colorScheme.primary;
        break;
    }

    final regionLabel = switch (region) {
      PriceRegion.turkey => 'Türkiye (Kapalıçarşı / Banka ort.)',
      PriceRegion.usa => 'ABD (COMEX / Kitco / Bloomberg)',
    };

    // Gram altın ayarı (ana sayfada hangi ayar gösterilsin)
    final gramPurity = ref.watch(selectedGramGoldPurityProvider);
    final bigparaByKey = ref.watch(bigparaByKeyProvider);

    // Altın dışı varlık seçiliyse canlı fiyatı tetikle (bir kez veya seçim/bölge değişince)
    final nonGoldState = ref.watch(liveNonGoldPriceProvider);
    if (selectedId != 'gold_gram' && asset != null) {
      final needFetch = nonGoldState.assetId != selectedId ||
          nonGoldState.useTry != useTry ||
          (!nonGoldState.isLoading && nonGoldState.result == null);
      if (needFetch) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(liveNonGoldPriceProvider.notifier).fetch(selectedId, useTry);
        });
      }
    }

    double? _num(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    // Seçili varlığa göre fiyat metni (altın = önce Bigpara, sonra gold API; diğerleri = assetPriceService)
    String priceText;
    String subtitle;
    bool showGoldError = false;
    if (selectedId == 'gold_gram') {
      double? basePrice;
      if (useTry && bigparaByKey != null) {
        final gram = bigparaByKey['gram_altin'];
        if (gram is Map<String, dynamic>) {
          final alis = _num(gram['alis']);
          final satis = _num(gram['satis']);
          basePrice = satis ?? alis ?? (alis != null && satis != null ? (alis + satis) / 2 : null);
        }
      }
      if (basePrice == null && state.price != null) basePrice = state.price!.pricePerGram;
      if (basePrice != null && basePrice > 0) {
        final ratio = switch (gramPurity) {
          GoldPurity.carat24 => 1.0,
          GoldPurity.carat22 => 22 / 24,
          GoldPurity.carat18 => 18 / 24,
          GoldPurity.carat14 => 14 / 24,
        };
        final price = basePrice * ratio;
        priceText = '${price.toStringAsFixed(2)} ${useTry ? 'TL' : 'USD'} / gr';
        subtitle = 'Son güncelleme: ${DateTime.now().toLocal().toString().substring(0, 16)}';
        showGoldError = false;
      } else {
        priceText = 'Henüz veri yok';
        subtitle = 'Güncel fiyatı almak için yenile. Backend (gold-api) çalışıyor mu?';
        showGoldError = state.errorMessage != null;
      }
    } else if (asset != null) {
      final res = selectedId == nonGoldState.assetId ? nonGoldState.result : null;
      if (nonGoldState.isLoading && nonGoldState.assetId == selectedId) {
        priceText = 'Yükleniyor...';
        subtitle = 'Güncelleniyor...';
      } else if (res?.price != null && res!.price! > 0) {
        priceText = '${res.price!.toStringAsFixed(2)} ${useTry ? 'TL' : 'USD'} / ${res.unitLabel}';
        subtitle = res.error != null
            ? res.error!
            : 'Son güncelleme: ${res.lastUpdated.toLocal()}';
      } else {
        priceText = 'Veri yok';
        subtitle = res?.error ?? 'Yüklenemedi. Yenile.';
      }
    } else {
      priceText = 'Henüz veri yok';
      subtitle = 'Fiyat verisi eklenebilir';
    }

    final selectedLabel = selectedId == 'gold_gram'
        ? 'Gram Altın (${_goldPurityLabel(gramPurity)})'
        : (asset?.name ?? 'Varlık');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst satır: Canlı göstergesi (sol) ve Yenile butonu (sağ) aynı hizada
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FadeTransition(
                  opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
                    CurvedAnimation(
                      parent: _liveController,
                      curve: Curves.easeInOut,
                    ),
                  ),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                      CurvedAnimation(
                        parent: _liveController,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 8, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Canlı',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: (selectedId == 'gold_gram' && state.isLoading) ||
                          (selectedId != 'gold_gram' && nonGoldState.isLoading)
                      ? null
                      : () {
                          if (selectedId == 'gold_gram') {
                            onRefresh();
                          } else {
                            ref
                                .read(liveNonGoldPriceProvider.notifier)
                                .fetch(selectedId, useTry);
                          }
                        },
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Fiyatı yenile',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$selectedLabel Fiyatı',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            // Varlık seçimi: canlı listesindekiler + Varlık ekle (katalogdan seçim)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...liveIds.map((id) {
                    SupportedAsset? a;
                    try {
                      a = allAssets.firstWhere((x) => x.id == id);
                    } catch (_) {}
                    if (a == null) return const SizedBox.shrink();
                    return _assetChip(context, ref, a.id, a.name, selectedId);
                  }),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18, color: Colors.green),
                      label: const Text('Varlık ekle'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SelectAssetForLivePage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Gram altın seçiliyse ayar seçici (24, 22, 18, 14) — varlık seçeneğinin altında
            if (selectedId == 'gold_gram') ...[
              Text(
                'Gram altın ayarı',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _gramPurityChip(context, ref, GoldPurity.carat24, '24 Ayar', gramPurity),
                    const SizedBox(width: 8),
                    _gramPurityChip(context, ref, GoldPurity.carat22, '22 Ayar', gramPurity),
                    const SizedBox(width: 8),
                    _gramPurityChip(context, ref, GoldPurity.carat18, '18 Ayar', gramPurity),
                    const SizedBox(width: 8),
                    _gramPurityChip(context, ref, GoldPurity.carat14, '14 Ayar', gramPurity),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<PriceRegion>(
              value: region,
              decoration: const InputDecoration(
                labelText: 'Bölge / Kaynak',
              ),
              items: const [
                DropdownMenuItem(
                  value: PriceRegion.turkey,
                  child: Text('Türkiye'),
                ),
                DropdownMenuItem(
                  value: PriceRegion.usa,
                  child: Text('ABD'),
                ),
              ],
              onChanged: (selectedId == 'gold_gram' && state.isLoading) ||
                      (selectedId != 'gold_gram' && nonGoldState.isLoading)
                  ? null
                  : (value) {
                      if (value != null) onRegionChanged(value);
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: trendColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    trendIcon,
                    color: trendColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        priceText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        regionLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (selectedId == 'gold_gram' && showGoldError && state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (selectedId != 'gold_gram' &&
                nonGoldState.assetId == selectedId &&
                nonGoldState.result?.error != null) ...[
              const SizedBox(height: 12),
              Text(
                nonGoldState.result!.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gramPurityChip(BuildContext context, WidgetRef ref, GoldPurity purity, String label, GoldPurity selected) {
    final isSelected = selected == purity;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(selectedGramGoldPurityProvider.notifier).state = purity;
      },
    );
  }

  Widget _assetChip(BuildContext context, WidgetRef ref, String id, String label, String selectedId) {
    final selected = selectedId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (_) {
          ref.read(selectedLiveAssetIdProvider.notifier).state = id;
        },
      ),
    );
  }

}


