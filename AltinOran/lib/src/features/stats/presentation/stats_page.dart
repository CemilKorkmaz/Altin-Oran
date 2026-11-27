import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/domain/gold_price.dart';
import '../../portfolio/presentation/portfolio_page.dart';
import '../../dashboard/presentation/pnl_details_page.dart';
import '../../dashboard/presentation/dashboard_page.dart' show PortfolioDistributionCard;
import '../application/stats_providers.dart';
import '../../../core/formatting.dart';
import '../../rates/presentation/rates_page.dart';
import '../../alerts/application/notification_service.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/presentation/alarm_notification_banner.dart';
import '../../goals/application/goals_providers.dart';
import '../../settings/application/settings_providers.dart';

/// Tarihi "7 Mart" gibi gün + ay adı formatında döndürür.
String _formatDayMonth(DateTime d) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

String _formatFullDate(DateTime d) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

void _showDayDetailPopup(BuildContext context, WidgetRef ref, StatsChartPoint point, {required bool isCost}) {
  final theme = Theme.of(context);
  final transactions = ref.read(transactionsProvider);
  final onDay = transactionsOnDay(transactions, point.date);
  final pnlColor = point.totalPnl >= 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatFullDate(point.date),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(ctx).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _DetailChip(label: 'Maliyet', value: '₺${formatMoney(point.costBasis)}'),
              _DetailChip(label: 'Kâr/Zarar', value: '${point.totalPnl >= 0 ? '+' : ''}₺${formatMoney(point.totalPnl)}', valueColor: pnlColor),
            ],
          ),
          if (onDay.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('O günkü işlemler', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...onDay.map((tx) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    tx.direction == TransactionDirection.buy ? Icons.add_circle_outline : Icons.remove_circle_outline,
                    size: 18,
                    color: tx.direction == TransactionDirection.buy ? const Color(0xFF42866B) : const Color(0xFFB75F59),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${tx.direction == TransactionDirection.buy ? "Alış" : "Satış"}: ${_assetLabel(tx)} ${tx.amount.toStringAsFixed(tx.assetType == AssetType.gramAltin || tx.assetType == AssetType.gumus ? 2 : 0)} ${_assetUnit(tx)}, ₺${formatMoney(tx.unitPrice)}/birim',
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Bu günde işlem yok.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
        ],
      ),
    ),
  );
}

String _assetLabel(InvestmentTransaction tx) {
  if (tx.assetType == AssetType.gramAltin) {
    final ayar = tx.goldPurity != null ? _goldPurityAyar(tx.goldPurity!) : null;
    return ayar != null ? 'Gram Altın ($ayar Ayar)' : 'Gram Altın';
  }
  if (tx.assetType == AssetType.gumus) return 'Gümüş';
  if (tx.assetType == AssetType.usd) return 'Dolar';
  if (tx.assetType == AssetType.eur) return 'Euro';
  if (tx.assetType == AssetType.btc) return 'Bitcoin';
  if (tx.assetType == AssetType.eth) return 'Ethereum';
  return tx.assetType.name;
}

String _goldPurityAyar(GoldPurity p) {
  switch (p) {
    case GoldPurity.carat24: return '24';
    case GoldPurity.carat22: return '22';
    case GoldPurity.carat18: return '18';
    case GoldPurity.carat14: return '14';
  }
}

String _assetUnit(InvestmentTransaction tx) {
  if (tx.assetType == AssetType.gramAltin || tx.assetType == AssetType.gumus || tx.assetType == AssetType.bilezik22) return 'gr';
  if (tx.assetType == AssetType.usd) return 'USD';
  if (tx.assetType == AssetType.eur) return 'EUR';
  if (tx.assetType == AssetType.btc) return 'BTC';
  if (tx.assetType == AssetType.eth) return 'ETH';
  return 'adet';
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          Text(value, style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class StatsPage extends ConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final summary = ref.watch(portfolioSummaryProvider);
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
          leading: Navigator.of(context).canPop() ? const BackButton() : null,
          title: const Text('İstatistikler'),
        ),
        body: transactions.isEmpty
            ? const _EmptyStatsView()
            : RefreshIndicator(
                onRefresh: () async {},
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      const SectionHeader(
                        icon: Icons.insights_rounded,
                        title: 'Özet',
                        subtitle: 'Kâr/zarar ve dağılım',
                      ),
                      const SizedBox(height: 8),
                    _GeneralStatsCard(
                      summary: summary,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PnlDetailsPage(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const _StatsTimeFilterChips(),
                    const SizedBox(height: 12),
                    const _CostOverTimeChart(),
                    const SizedBox(height: 16),
                    const _RealizedPnlOverTimeChart(),
                    const SizedBox(height: 16),
                    const _MonthlyPnlBarChart(),
                    const SizedBox(height: 16),
                    const PortfolioDistributionCard(),
                    const SizedBox(height: 16),
                    const _PerAssetPnlCard(),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}

class _StatsTimeFilterChips extends ConsumerWidget {
  const _StatsTimeFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(statsTimeRangeProvider);
    final notifier = ref.read(statsTimeRangeProvider.notifier);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: StatsTimeRange.values.map((range) {
        final isSelected = selected == range;
        return FilterChip(
          label: Text(range.label),
          selected: isSelected,
          onSelected: (_) => notifier.state = range,
        );
      }).toList(),
    );
  }
}

class _CostOverTimeChart extends ConsumerStatefulWidget {
  const _CostOverTimeChart();

  @override
  ConsumerState<_CostOverTimeChart> createState() => _CostOverTimeChartState();
}

class _CostOverTimeChartState extends ConsumerState<_CostOverTimeChart> {
  int? _touchedSpotIndex;

  void _onChartTap(FlTouchEvent event, LineTouchResponse? response, List<StatsChartPoint> points) {
    if (event is! FlTapUpEvent || response?.lineBarSpots == null || response!.lineBarSpots!.isEmpty) return;
    final spot = response.lineBarSpots!.first;
    final index = spot.x.toInt().clamp(0, points.length - 1);
    if (_touchedSpotIndex == index) {
      _showDayDetailPopup(context, ref, points[index], isCost: true);
      setState(() => _touchedSpotIndex = null);
    } else {
      setState(() => _touchedSpotIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(statsChartDataProvider);
    final (rangeStart, rangeEnd) = ref.watch(statsTimeRangeDatesProvider);
    final theme = Theme.of(context);
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Maliyet (birikim) zaman içinde — yeterli veri yok',
            style: theme.textTheme.titleSmall,
          ),
        ),
      );
    }
    final lastDay = rangeEnd.subtract(const Duration(days: 1));
    final minCost = points.map((e) => e.costBasis).reduce((a, b) => a < b ? a : b);
    final maxCost = points.map((e) => e.costBasis).reduce((a, b) => a > b ? a : b);
    final span = (maxCost - minCost).clamp(1.0, double.infinity);
    final spots = points.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value.costBasis - minCost) / span)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maliyet (birikim) zaman içinde',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_touchedSpotIndex != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_formatDayMonth(points[_touchedSpotIndex!].date)}: ₺${formatMoney(points[_touchedSpotIndex!].costBasis)}',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: theme.colorScheme.primary,
                          strokeWidth: 1.5,
                          strokeColor: theme.colorScheme.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(show: true, color: theme.colorScheme.primary.withOpacity(0.15)),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (event, response) => _onChartTap(event, response, points),
                    touchSpotThreshold: 18,
                    getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((i) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: theme.colorScheme.primary.withOpacity(0.5), strokeWidth: 1),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, pct, data, idx) => FlDotCirclePainter(
                            radius: 5,
                            color: theme.colorScheme.primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.round().clamp(0, points.length - 1);
                          final d = points[idx].date;
                          final showAll = points.length <= 8;
                          final isFirst = idx == 0;
                          final isLast = idx == points.length - 1;
                          if (!showAll && !isFirst && !isLast) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(top: 8, left: isFirst ? 4 : 2, right: isLast ? 4 : 2),
                            child: Text(_formatDayMonth(d), style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
                duration: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '₺${formatMoney(points.last.costBasis)}',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              'Dönem: ${_formatDayMonth(rangeStart)} - ${_formatDayMonth(lastDay)}',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RealizedPnlOverTimeChart extends ConsumerStatefulWidget {
  const _RealizedPnlOverTimeChart();

  @override
  ConsumerState<_RealizedPnlOverTimeChart> createState() => _RealizedPnlOverTimeChartState();
}

class _RealizedPnlOverTimeChartState extends ConsumerState<_RealizedPnlOverTimeChart> {
  int? _touchedSpotIndex;

  void _onChartTap(FlTouchEvent event, LineTouchResponse? response, List<StatsChartPoint> points) {
    if (event is! FlTapUpEvent || response?.lineBarSpots == null || response!.lineBarSpots!.isEmpty) return;
    final spot = response.lineBarSpots!.first;
    final index = spot.x.toInt().clamp(0, points.length - 1);
    if (_touchedSpotIndex == index) {
      _showDayDetailPopup(context, ref, points[index], isCost: false);
      setState(() => _touchedSpotIndex = null);
    } else {
      setState(() => _touchedSpotIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(statsChartDataProvider);
    final (rangeStart, rangeEnd) = ref.watch(statsTimeRangeDatesProvider);
    final theme = Theme.of(context);
    if (points.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Toplam kâr/zarar zaman içinde — yeterli veri yok',
            style: theme.textTheme.titleSmall,
          ),
        ),
      );
    }
    final lastDay = rangeEnd.subtract(const Duration(days: 1));
    final minPnl = points.map((e) => e.totalPnl).reduce((a, b) => a < b ? a : b);
    final maxPnl = points.map((e) => e.totalPnl).reduce((a, b) => a > b ? a : b);
    final span = (maxPnl - minPnl).clamp(1.0, double.infinity);
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), (e.value.totalPnl - minPnl) / span))
        .toList();
    final pnlColor = points.last.totalPnl >= 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Toplam kâr/zarar zaman içinde',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_touchedSpotIndex != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (points[_touchedSpotIndex!].totalPnl >= 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_formatDayMonth(points[_touchedSpotIndex!].date)}: ${points[_touchedSpotIndex!].totalPnl >= 0 ? '+' : ''}₺${formatMoney(points[_touchedSpotIndex!].totalPnl)}',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: pnlColor),
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: pnlColor,
                      barWidth: 2,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 4,
                          color: pnlColor,
                          strokeWidth: 1.5,
                          strokeColor: theme.colorScheme.surface,
                        ),
                      ),
                      belowBarData: BarAreaData(show: true, color: pnlColor.withOpacity(0.2)),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchCallback: (event, response) => _onChartTap(event, response, points),
                    touchSpotThreshold: 18,
                    getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes.map((i) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: pnlColor.withOpacity(0.5), strokeWidth: 1),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, pct, data, idx) => FlDotCirclePainter(
                            radius: 5,
                            color: pnlColor,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.round().clamp(0, points.length - 1);
                          final d = points[idx].date;
                          final showAll = points.length <= 8;
                          final isFirst = idx == 0;
                          final isLast = idx == points.length - 1;
                          if (!showAll && !isFirst && !isLast) return const SizedBox.shrink();
                          return Padding(
                            padding: EdgeInsets.only(top: 8, left: isFirst ? 4 : 2, right: isLast ? 4 : 2),
                            child: Text(_formatDayMonth(d), style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
                duration: const Duration(milliseconds: 200),
              ),
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final last = points.last;
                final cost = last.costBasis;
                final pnl = last.totalPnl;
                final ratio = cost > 0 ? (pnl / cost * 100) : 0.0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₺${formatMoney(pnl)} (${ratio.toStringAsFixed(1)}%)',
                      style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: pnlColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Dönem: ${_formatDayMonth(rangeStart)} - ${_formatDayMonth(lastDay)}',
                      style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyPnlBarChart extends ConsumerWidget {
  const _MonthlyPnlBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthly = ref.watch(monthlyPnlProvider);
    final theme = Theme.of(context);
    if (monthly.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Aylık kâr/zarar — yeterli veri yok',
            style: theme.textTheme.titleSmall,
          ),
        ),
      );
    }
    final count = monthly.length;
    final maxAbs = monthly.map((e) => e.pnl.abs()).reduce((a, b) => a > b ? a : b);
    final maxY = (maxAbs * 1.3).clamp(500.0, double.infinity);
    final barWidth = count <= 2 ? 32.0 : (count <= 4 ? 22.0 : (count <= 6 ? 18.0 : 14.0));
    final groupsSpace = count <= 2 ? 28.0 : (count <= 4 ? 18.0 : 12.0);
    final barGroups = monthly.asMap().entries.map((e) {
      final pnl = e.value.pnl;
      final color = pnl >= 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59);
      final clamped = pnl.clamp(-maxY, maxY);
      final fromY = clamped <= 0 ? clamped : 0.0;
      final toY = clamped >= 0 ? clamped : 0.0;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            fromY: fromY,
            toY: toY,
            color: color,
            width: barWidth,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(clamped >= 0 ? 6 : 0),
              bottom: Radius.circular(clamped <= 0 ? 6 : 0),
            ),
          ),
        ],
        showingTooltipIndicators: [],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Aylık kâr/zarar',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  groupsSpace: groupsSpace,
                  maxY: maxY,
                  minY: -maxY,
                  barGroups: barGroups,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= monthly.length) return const SizedBox.shrink();
                          final p = monthly[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  p.monthLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${p.pnl >= 0 ? '+' : ''}₺${formatMoney(p.pnl)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: p.pnl >= 0 ? const Color(0xFF42866B) : const Color(0xFFB75F59),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      if (value == 0) {
                        return FlLine(
                          color: theme.colorScheme.outline.withOpacity(0.4),
                          strokeWidth: 1.5,
                        );
                      }
                      return FlLine(color: Colors.transparent, strokeWidth: 0);
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final p = monthly[group.x];
                        return BarTooltipItem(
                          '${p.monthLabel}\n${p.pnl >= 0 ? '+' : ''}₺${formatMoney(p.pnl)}',
                          TextStyle(
                            color: theme.colorScheme.onInverseSurface,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                duration: const Duration(milliseconds: 200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStatsView extends StatelessWidget {
  const _EmptyStatsView();

  @override
  Widget build(BuildContext context) {
    return const EmptyStateView(
      icon: Icons.insights_outlined,
      title: 'Henüz istatistik yok',
      description: 'İşlemlerinizi ekledikçe birikiminizin gelişimi burada görünecek.',
    );
  }
}

class _GeneralStatsCard extends StatelessWidget {
  const _GeneralStatsCard({required this.summary, this.onTap});

  final PortfolioSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCost = summary.totalCost;
    final currentValue =
        summary.totalCurrentValue > 0 ? summary.totalCurrentValue : totalCost;
    final totalPnl = summary.totalProfitLoss;
    final realized = summary.realizedProfitLoss;
    final unrealized = summary.unrealizedProfitLoss;

    Color pnlColor(double v) {
      if (v > 0) return const Color(0xFF42866B);
      if (v < 0) return const Color(0xFFB75F59);
      return theme.colorScheme.onSurface.withOpacity(0.7);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Genel İstatistikler',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _StatRow(
                label: 'Açık pozisyon maliyeti',
                value: '₺${formatMoney(totalCost)}',
              ),
              const SizedBox(height: 4),
              _StatRow(
                label: 'Güncel değer (tahmini)',
                value: '₺${formatMoney(currentValue)}',
              ),
              const Divider(height: 20),
              _StatRow(
                label: 'Toplam kâr / zarar',
                value: '₺${formatMoney(totalPnl)}',
                valueColor: pnlColor(totalPnl),
              ),
              const SizedBox(height: 4),
              _StatRow(
                label: 'Satışlardan kâr/zarar',
                value: '₺${formatMoney(realized)}',
                valueColor: pnlColor(realized),
              ),
              const SizedBox(height: 2),
              _StatRow(
                label: 'Elde tutulan pozisyon kâr/zararı',
                value: '₺${formatMoney(unrealized)}',
                valueColor: pnlColor(unrealized),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8)),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Varlık bazlı toplam kâr/zarar listesi.
class _PerAssetPnlCard extends ConsumerWidget {
  const _PerAssetPnlCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    final goldState = ref.watch(goldPriceProvider);
    final currentGramPrice = goldPricePerGramInTry(goldState.price, ref.watch(usdTryRateProvider).rate);

    // Altına çevrilebilir varlıklar için, ayar bazında kâr/zarar dağılımı.
    final sorted = [...transactions]
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final Map<_AssetPurityKey, double> remainingGramsPerKey = {};
    final Map<_AssetPurityKey, double> remainingCostPerKey = {};
    final Map<_AssetPurityKey, double> realizedPerKey = {};

    for (final tx in sorted) {
      final grams = tx.goldEquivalentGrams;
      if (grams == 0) continue;
      final key = _AssetPurityKey(tx.assetType, tx.goldPurity);

      final remainingGrams = remainingGramsPerKey[key] ?? 0;
      final remainingCost = remainingCostPerKey[key] ?? 0;

      if (tx.direction == TransactionDirection.buy) {
        remainingGramsPerKey[key] = remainingGrams + grams;
        remainingCostPerKey[key] = remainingCost + tx.totalValue;
      } else {
        if (remainingGrams <= 0) continue;

        final sellGrams = grams.clamp(0, remainingGrams);
        final avgCostPerGram =
            remainingGrams > 0 ? (remainingCost / remainingGrams) : 0;
        final costRemoved = sellGrams * avgCostPerGram;
        final saleProceeds = (tx.totalValue / grams) * sellGrams;
        final realizedForThisTx = saleProceeds - costRemoved;

        realizedPerKey[key] =
            (realizedPerKey[key] ?? 0) + realizedForThisTx;

        remainingGramsPerKey[key] = remainingGrams - sellGrams;
        remainingCostPerKey[key] = remainingCost - costRemoved;
      }
    }

    final Map<_AssetPurityKey, double> unrealizedPerKey = {};
    if (currentGramPrice != null) {
      for (final entry in remainingGramsPerKey.entries) {
        final key = entry.key;
        final grams = entry.value;
        if (grams <= 0) continue;

        final currentValue = grams * currentGramPrice;
        final remainingCost = remainingCostPerKey[key] ?? 0;
        unrealizedPerKey[key] = currentValue - remainingCost;
      }
    }

    final Map<_AssetPurityKey, double> totalPerKey = {};
    final allKeys = {
      ...realizedPerKey.keys,
      ...unrealizedPerKey.keys,
    };
    for (final key in allKeys) {
      final realized = realizedPerKey[key] ?? 0;
      final unrealized = unrealizedPerKey[key] ?? 0;
      final total = realized + unrealized;
      if (total != 0) {
        totalPerKey[key] = total;
      }
    }

    final entries = totalPerKey.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Henüz varlık bazlı kâr/zarar oluşmamış.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Varlık bazlı kâr/zarar',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final key = e.key;
              final asset = key.assetType;
              final pnl = e.value;
              final color =
                  pnl > 0 ? const Color(0xFF42866B) : (pnl < 0 ? const Color(0xFFB75F59) : Theme.of(context).colorScheme.onSurface.withOpacity(0.7));
              final label = _isGoldAssetType(asset) && key.goldPurity != null
                  ? '${_assetTypeLabel(asset)} (${_goldPurityLabel(key.goldPurity!)})'
                  : _assetTypeLabel(asset);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AssetDetailPage(
                          assetType: asset,
                          goldPurity: key.goldPurity,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: _assetColor(asset),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      Text(
                        '₺${formatMoney(pnl)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

Color _assetColor(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
      return const Color(0xFFB8860B);
    case AssetType.ceyrek:
      return const Color(0xFFF59E0B);
    case AssetType.yarim:
      return const Color(0xFF10B981);
    case AssetType.tam:
      return const Color(0xFFEC4899);
    case AssetType.cumhuriyet:
      return const Color(0xFF8B5CF6);
    case AssetType.bilezik22:
      return const Color(0xFFF97316);
    case AssetType.onsAltin:
      return const Color(0xFF0EA5E9);
    case AssetType.gumus:
      return const Color(0xFF9CA3AF);
    case AssetType.platin:
      return const Color(0xFFE5E4E2);
    case AssetType.paladyum:
      return const Color(0xFFB4B4B4);
    case AssetType.usd:
    case AssetType.eur:
      return const Color(0xFF4B5563);
    case AssetType.btc:
      return const Color(0xFFF7931A);
    case AssetType.eth:
      return const Color(0xFF627EEA);
    case AssetType.otherCrypto:
      return const Color(0xFF22C55E);
    case AssetType.stock:
      return const Color(0xFF6B7280);
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

class _AssetPurityKey {
  const _AssetPurityKey(this.assetType, this.goldPurity);

  final AssetType assetType;
  final GoldPurity? goldPurity;

  @override
  bool operator ==(Object other) {
    return other is _AssetPurityKey &&
        other.assetType == assetType &&
        other.goldPurity == goldPurity;
  }

  @override
  int get hashCode => Object.hash(assetType, goldPurity);
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


