import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/application/eur_try_rate_providers.dart';
import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';

/// İstatistikler sayfasında seçilen dönem.
enum StatsTimeRange {
  today,
  thisWeek,
  last7Days,
  thisMonth,
  thisYear,
  all,
}

extension StatsTimeRangeX on StatsTimeRange {
  String get label {
    switch (this) {
      case StatsTimeRange.today:
        return 'Bugün';
      case StatsTimeRange.thisWeek:
        return 'Bu hafta';
      case StatsTimeRange.last7Days:
        return 'Son 7 gün';
      case StatsTimeRange.thisMonth:
        return 'Bu ay';
      case StatsTimeRange.thisYear:
        return 'Bu yıl';
      case StatsTimeRange.all:
        return 'Tümü';
    }
  }
}

final statsTimeRangeProvider =
    StateProvider<StatsTimeRange>((ref) => StatsTimeRange.all);

/// Seçilen döneme göre (start, end) tarih aralığı.
/// end her zaman exclusive (dönemin ertesinin 00:00'ı).
(DateTime start, DateTime end) _rangeFor(StatsTimeRange range) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  switch (range) {
    case StatsTimeRange.today:
      return (today, today.add(const Duration(days: 1)));
    case StatsTimeRange.thisWeek:
      // Hafta pazartesiden başlar (weekday: 1 = Pazartesi, 7 = Pazar).
      final weekday = now.weekday;
      final monday = today.subtract(Duration(days: weekday - 1));
      return (monday, today.add(const Duration(days: 1)));
    case StatsTimeRange.last7Days:
      // Tam 7 gün: bugün dahil geriye 7 gün (bugün-6 .. bugün).
      return (today.subtract(const Duration(days: 6)), today.add(const Duration(days: 1)));
    case StatsTimeRange.thisMonth:
      return (DateTime(now.year, now.month, 1), today.add(const Duration(days: 1)));
    case StatsTimeRange.thisYear:
      return (DateTime(now.year, 1, 1), today.add(const Duration(days: 1)));
    case StatsTimeRange.all:
      return (DateTime(now.year - 10, 1, 1), today.add(const Duration(days: 1)));
  }
}

/// Seçilen dönemin başlangıç ve bitiş tarihleri (UI'da "Dönem" etiketi için).
/// "Tümü" seçiliyse ilk işlem günü – bugün gösterilir (10 yıl önce değil).
final statsTimeRangeDatesProvider = Provider<(DateTime start, DateTime end)>((ref) {
  final range = ref.watch(statsTimeRangeProvider);
  final (rangeStart, rangeEnd) = _rangeFor(range);
  if (range != StatsTimeRange.all) return (rangeStart, rangeEnd);
  final transactions = ref.watch(transactionsProvider);
  if (transactions.isEmpty) return (rangeStart, rangeEnd);
  final sorted = [...transactions]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final firstDay = DateTime(
    sorted.first.dateTime.year,
    sorted.first.dateTime.month,
    sorted.first.dateTime.day,
  );
  return (firstDay, rangeEnd);
});

/// Seçilen dönemdeki işlemler (kronolojik).
final filteredTransactionsProvider = Provider<List<InvestmentTransaction>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final range = ref.watch(statsTimeRangeProvider);
  final (start, end) = _rangeFor(range);
  return transactions
      .where((t) =>
          !t.dateTime.isBefore(start) && t.dateTime.isBefore(end))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
});

/// Belirli bir günde yapılan işlemler (gün detay popup için).
List<InvestmentTransaction> transactionsOnDay(List<InvestmentTransaction> all, DateTime day) {
  final dayStart = DateTime(day.year, day.month, day.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return all
      .where((t) => !t.dateTime.isBefore(dayStart) && t.dateTime.isBefore(dayEnd))
      .toList()
    ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
}

/// Grafik için günlük seri:
/// - [costBasis]: o güne kadarki toplam maliyet (cost basis)
/// - [totalPnl]: bugünkü fiyata göre toplam kâr/zarar
class StatsChartPoint {
  const StatsChartPoint({
    required this.date,
    required this.costBasis,
    required this.totalPnl,
  });
  final DateTime date;
  final double costBasis;
  final double totalPnl;
}

/// Seçilen dönemdeki işlemlere göre günlük maliyet ve toplam K/Z serisi.
/// Her işlem günü + dönem başı/sonu için bir nokta üretir.
final statsChartDataProvider = Provider<List<StatsChartPoint>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final range = ref.watch(statsTimeRangeProvider);
  final (rangeStart, rangeEnd) = _rangeFor(range);

  // Bugünkü fiyatlar (grafikteki kâr/zarar hesabı için).
  final goldState = ref.watch(goldPriceProvider);
  final currentGramPrice = goldState.price?.pricePerGram;
  final usdRate = ref.watch(usdTryRateProvider).rate;
  final eurRate = ref.watch(eurTryRateProvider).rate;
  final currentFxPricePerUnit = <AssetType, double>{};
  if (usdRate != null) currentFxPricePerUnit[AssetType.usd] = usdRate;
  if (eurRate != null) currentFxPricePerUnit[AssetType.eur] = eurRate;

  final rangeEndDay = rangeEnd.subtract(const Duration(days: 1));
  if (transactions.isEmpty) {
    return [
      StatsChartPoint(date: rangeStart, costBasis: 0, totalPnl: 0),
      StatsChartPoint(date: rangeEndDay, costBasis: 0, totalPnl: 0),
    ];
  }

  final sorted = [...transactions]..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  // Tarih karşılaştırmasında sadece gün kullan (saat/dilim kaynaklı eksik gün kalmasın).
  final rangeStartDay = DateTime(rangeStart.year, rangeStart.month, rangeStart.day);
  final rangeEndDayNormalized = DateTime(rangeEndDay.year, rangeEndDay.month, rangeEndDay.day);

  final dates = <DateTime>{};
  // "Tümü" seçiliyse dönem başı olarak ilk işlem gününü kullan (10 yıl önce 1 Ocak eklenmesin).
  if (range == StatsTimeRange.all && sorted.isNotEmpty) {
    final firstTx = sorted.first;
    dates.add(DateTime(firstTx.dateTime.year, firstTx.dateTime.month, firstTx.dateTime.day));
  } else {
    dates.add(rangeStartDay);
  }
  dates.add(rangeEndDayNormalized);
  for (final t in sorted) {
    final tDay = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
    if (!tDay.isBefore(rangeStartDay) && !tDay.isAfter(rangeEndDayNormalized)) {
      dates.add(tDay);
    }
  }
  final sortedDates = dates.toList()..sort((a, b) => a.compareTo(b));
  if (sortedDates.isEmpty) {
    return [
      StatsChartPoint(date: rangeStart, costBasis: 0, totalPnl: 0),
      StatsChartPoint(date: rangeEndDay, costBasis: 0, totalPnl: 0),
    ];
  }

  final result = <StatsChartPoint>[];
  for (final day in sortedDates) {
    final endOfDay = day.add(const Duration(days: 1));
    final upTo = sorted.where((t) => t.dateTime.isBefore(endOfDay)).toList();
    double realizedPnl = 0;

    final Map<Object, double> remainingGrams = {};
    final Map<Object, double> remainingCost = {};
    final Map<Object, double> remainingUnitsFx = {};
    final Map<Object, double> remainingCostFx = {};

    for (final tx in upTo) {
      final key = _key(tx);
      final grams = tx.goldEquivalentGrams;
      final isFx = tx.assetType == AssetType.usd || tx.assetType == AssetType.eur;

      if (isFx) {
        final units = tx.amount;
        if (units > 0) {
          final remU = remainingUnitsFx[key] ?? 0;
          final remC = remainingCostFx[key] ?? 0;
          if (tx.direction == TransactionDirection.buy) {
            remainingUnitsFx[key] = remU + units;
            remainingCostFx[key] = remC + tx.totalValue;
          } else {
            if (remU > 0) {
              final sellU = units.clamp(0, remU);
              final avgCost = remU > 0 ? remC / remU : 0;
              final costRemoved = sellU * avgCost;
              final proceeds = (tx.totalValue / units) * sellU;
              realizedPnl += proceeds - costRemoved;
              remainingUnitsFx[key] = remU - sellU;
              remainingCostFx[key] = remC - costRemoved;
            }
          }
        }
      } else if (grams > 0) {
        final remG = remainingGrams[key] ?? 0;
        final remC = remainingCost[key] ?? 0;
        if (tx.direction == TransactionDirection.buy) {
          remainingGrams[key] = remG + grams;
          remainingCost[key] = remC + tx.totalValue;
        } else {
          if (remG > 0) {
            final sellG = grams.clamp(0, remG);
            final avgCost = remG > 0 ? remC / remG : 0;
            final costRemoved = sellG * avgCost;
            final proceeds = (tx.totalValue / grams) * sellG;
            realizedPnl += proceeds - costRemoved;
            remainingGrams[key] = remG - sellG;
            remainingCost[key] = remC - costRemoved;
          }
        }
      }
    }
    double totalRemainingCost = 0;
    for (final c in remainingCost.values) {
      totalRemainingCost += c;
    }
    for (final c in remainingCostFx.values) {
      totalRemainingCost += c;
    }

    double totalCurrentValue = 0;

    // Altın ve altına endeksli varlıklar için güncel toplam değer.
    if (currentGramPrice != null) {
      for (final grams in remainingGrams.values) {
        if (grams <= 0) continue;
        totalCurrentValue += grams * currentGramPrice;
      }
    }

    // Döviz pozisyonlarının güncel değeri.
    for (final entry in remainingUnitsFx.entries) {
      final key = entry.key;
      final units = entry.value;
      if (units <= 0) continue;
      final asset = key is AssetType ? key : null;
      if (asset == null) continue;
      final currentPrice = currentFxPricePerUnit[asset];
      if (currentPrice == null) continue;
      totalCurrentValue += units * currentPrice;
    }

    final unrealizedPnl = totalCurrentValue - totalRemainingCost;
    final totalPnl = realizedPnl + unrealizedPnl;

    result.add(StatsChartPoint(
      date: day,
      costBasis: totalRemainingCost,
      totalPnl: totalPnl,
    ));
  }
  return result;
});

/// Aylık kâr/zarar: ay etiketi ve o aydaki toplam K/Z değişimi.
class MonthlyPnlPoint {
  const MonthlyPnlPoint({required this.monthLabel, required this.pnl});
  final String monthLabel;
  final double pnl;
}

/// Seçilen dönemdeki aylık kâr/zarar serisi (çubuk grafik için).
final monthlyPnlProvider = Provider<List<MonthlyPnlPoint>>((ref) {
  final points = ref.watch(statsChartDataProvider);
  if (points.length < 2) return [];
  final result = <MonthlyPnlPoint>[];
  final months = <int, List<StatsChartPoint>>{};
  for (final p in points) {
    final key = p.date.year * 100 + p.date.month;
    months.putIfAbsent(key, () => []).add(p);
  }
  final sortedKeys = months.keys.toList()..sort();
  const monthNames = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  for (final key in sortedKeys) {
    final list = months[key]!;
    list.sort((a, b) => a.date.compareTo(b.date));
    final first = list.first.totalPnl;
    final last = list.last.totalPnl;
    final pnl = last - first;
    final year = key ~/ 100;
    final month = key % 100;
    result.add(MonthlyPnlPoint(
      monthLabel: '${monthNames[month - 1]} $year',
      pnl: pnl,
    ));
  }
  return result;
});

Object _key(InvestmentTransaction tx) {
  if (tx.assetType == AssetType.usd || tx.assetType == AssetType.eur) {
    return tx.assetType;
  }
  return (tx.assetType, tx.goldPurity);
}
