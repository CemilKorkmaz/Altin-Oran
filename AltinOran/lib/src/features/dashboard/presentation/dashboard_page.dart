import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
          title: const Text('Genel bakış'),
          actions: [Padding(padding: const EdgeInsets.only(right: 20), child: Center(child: Container(width: 38, height: 38, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(13)), child: Icon(CupertinoIcons.sparkles, size: 18, color: Theme.of(context).colorScheme.primary))))],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.read(lastRatesRefreshAtProvider.notifier).state = DateTime.now();
            await Future.wait([
              ref.read(bigparaByKeyProvider.notifier).refresh(),
              ref.read(goldPriceProvider.notifier).refresh(),
              ref.read(usdTryRateProvider.notifier).refresh(),
              ref.read(eurTryRateProvider.notifier).refresh(),
            ]);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                  child: Text('Birikiminiz, bir bakışta.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
                ),
                _PortfolioHero(
                  amount: formatDisplayCurrency(
                    summary.totalCurrentValue > 0 ? summary.totalCurrentValue : summary.totalCost,
                    displayCurrency, usdRateState.rate, eurRateState.rate,
                  ),
                  amountLabel: summary.totalCurrentValue > 0 ? 'Tahmini değer (eksik fiyatlar olabilir)' : 'Toplam maliyet',
                  profitLoss: summary.totalProfitLoss,
                  profitText: summary.totalCurrentValue == 0 && summary.totalCost > 0 ? '—' : formatDisplayCurrency(
                    summary.totalProfitLoss.abs(), displayCurrency, usdRateState.rate, eurRateState.rate,
                  ),
                  todayText: 'Bugün: —',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PnlDetailsPage())),
                ),
                const SizedBox(height: 24),
                const SectionHeader(icon: Icons.show_chart_rounded, title: 'Piyasa', subtitle: 'Takip ettiğiniz varlıklar'),
                GoldPriceCard(
                  state: goldState,
                  region: selectedRegion,
                  onRegionChanged: (region) {
                    ref.read(selectedRegionProvider.notifier).state = region;
                    ref.read(goldPriceProvider.notifier).refresh();
                  },
                  onRefresh: () async {
                    ref.read(lastRatesRefreshAtProvider.notifier).state = DateTime.now();
                    await Future.wait([
                      ref.read(bigparaByKeyProvider.notifier).refresh(),
                      ref.read(goldPriceProvider.notifier).refresh(),
                    ]);
                  },
                ),
                const SizedBox(height: 24),
                const SectionHeader(icon: Icons.pie_chart_outline_rounded, title: 'Portföy dağılımı', subtitle: 'Birikimlerinizin genel görünümü'),
                const PortfolioDistributionCard(),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _PortfolioHero extends StatelessWidget {
  const _PortfolioHero({required this.amount, required this.amountLabel, required this.profitLoss, required this.profitText, required this.todayText, required this.onTap});
  final String amount;
  final String amountLabel;
  final double profitLoss;
  final String profitText;
  final String todayText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ink = Color(0xFF1D222C);
    const gold = Color(0xFFE4C68B);
    return Material(
      color: ink, borderRadius: BorderRadius.circular(26), clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Stack(children: [
        Positioned(right: -52, top: -70, child: Container(width: 180, height: 180,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .07), width: 28)))),
        Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: gold.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
              child: const Icon(CupertinoIcons.chart_pie_fill, color: gold, size: 17)),
            const SizedBox(width: 10),
            const Expanded(child: Text('PORTFÖY ÖZETİ', style: TextStyle(color: Color(0xFFD6C6A8), fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700))),
            Icon(CupertinoIcons.arrow_up_right, color: Colors.white.withValues(alpha: .55), size: 17),
          ]),
          const SizedBox(height: 26),
          Text(amountLabel, style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC1C8))),
          const SizedBox(height: 7),
          Text(amount, maxLines: 2, style: theme.textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 32, height: 1.1, fontWeight: FontWeight.w700, letterSpacing: -1.3)),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: .13)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Tahmini kâr / zarar', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFFBEC1C8)))),
            Flexible(child: Text('${profitText == '—' ? '' : profitLoss < 0 ? '−' : profitLoss > 0 ? '+' : ''}$profitText', textAlign: TextAlign.end, style: theme.textTheme.titleSmall?.copyWith(color: gold, fontWeight: FontWeight.w700))),
          ]),
        ])),
      ])),
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
      ringColor = const Color(0xFF42866B);
    } else if (isLoss) {
      ringColor = const Color(0xFFB75F59);
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
    final displayCurrency = ref.watch(appSettingsProvider).displayCurrency;
    final usdRate = ref.watch(usdTryRateProvider).rate;
    final gold = goldState.price;
    final currentGramPrice = gold == null ? null : gold.region == PriceRegion.turkey
        ? gold.pricePerGram : usdRate == null ? null : gold.pricePerGram * usdRate;
    final eurRate = ref.watch(eurTryRateProvider).rate;

    if (transactions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(children: [
            Icon(CupertinoIcons.chart_pie, color: Theme.of(context).colorScheme.primary, size: 25),
            const SizedBox(width: 14),
            Expanded(child: Text('İlk işleminizi eklediğinizde dağılımınız burada görünecek.', style: Theme.of(context).textTheme.bodySmall)),
          ]),
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

class _GoldPriceCardState extends ConsumerState<GoldPriceCard> {
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
      if (basePrice == null && state.price != null && state.price!.region == region) basePrice = state.price!.pricePerGram;
      if (basePrice != null && basePrice > 0) {
        final ratio = switch (gramPurity) {
          GoldPurity.carat24 => 1.0,
          GoldPurity.carat22 => 22 / 24,
          GoldPurity.carat18 => 18 / 24,
          GoldPurity.carat14 => 14 / 24,
        };
        final price = basePrice * ratio;
        priceText = '${price.toStringAsFixed(2)} ${useTry ? 'TL' : 'USD'} / gr';
        subtitle = state.price != null && basePrice == state.price!.pricePerGram
            ? 'Son güncelleme: ${state.price!.lastUpdated.toLocal().toString().substring(0, 16)}'
            : 'Kaynak: Bigpara';
      } else {
        priceText = 'Henüz veri yok';
        subtitle = 'Fiyat alınamadı. Yenileyerek tekrar deneyin.';
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
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
              child: Icon(CupertinoIcons.chart_bar_alt_fill, color: theme.colorScheme.primary, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(selectedLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text('Referans fiyat', style: theme.textTheme.bodySmall),
            ])),
            IconButton(
              onPressed: (selectedId == 'gold_gram' && state.isLoading) || (selectedId != 'gold_gram' && nonGoldState.isLoading)
                  ? null : () { if (selectedId == 'gold_gram') { onRefresh(); } else { ref.read(liveNonGoldPriceProvider.notifier).fetch(selectedId, useTry); } },
              icon: const Icon(CupertinoIcons.refresh, size: 20), tooltip: 'Fiyatı yenile',
            ),
          ]),
          const SizedBox(height: 22),
          Text(priceText, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -.8)),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 14),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            ...liveIds.map((id) {
              SupportedAsset? a;
              try { a = allAssets.firstWhere((x) => x.id == id); } catch (_) {}
              if (a == null) return const SizedBox.shrink();
              return _assetChip(context, ref, a.id, a.name, selectedId);
            }),
            ActionChip(avatar: Icon(CupertinoIcons.add, size: 16, color: theme.colorScheme.primary), label: const Text('Ekle'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SelectAssetForLivePage()))),
          ])),
          if (selectedId == 'gold_gram') ...[
            const SizedBox(height: 12),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _gramPurityChip(context, ref, GoldPurity.carat24, '24 ayar', gramPurity),
              const SizedBox(width: 6), _gramPurityChip(context, ref, GoldPurity.carat22, '22 ayar', gramPurity),
              const SizedBox(width: 6), _gramPurityChip(context, ref, GoldPurity.carat18, '18 ayar', gramPurity),
              const SizedBox(width: 6), _gramPurityChip(context, ref, GoldPurity.carat14, '14 ayar', gramPurity),
            ])),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Para birimi', style: theme.textTheme.bodySmall)),
            CupertinoSlidingSegmentedControl<PriceRegion>(
              groupValue: region,
              children: const {PriceRegion.turkey: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('TL')), PriceRegion.usa: Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('USD'))},
              onValueChanged: (value) { if (value != null) onRegionChanged(value); },
            ),
          ]),
        ]),
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


