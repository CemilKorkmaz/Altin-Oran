import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../transactions/application/transactions_providers.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../domain/goal.dart';

/// Gram altın / bilezik için ayarlı bakiye anahtarı: (assetType, customAssetId, goldPurity).
/// Diğer varlıklar için purity null.
typedef _AssetKey = (AssetType, String, GoldPurity?);

/// Tüm hedefleri tutan provider.
final goalsProvider =
    StateNotifierProvider<GoalsNotifier, List<Goal>>((ref) => GoalsNotifier());

/// Tamamlanan hedefler için kutlama popup'ı gösterildi mi (tek seferlik).
final completedGoalCelebrationShownProvider =
    StateProvider<Set<String>>((ref) => {});

class GoalsNotifier extends StateNotifier<List<Goal>> {
  GoalsNotifier() : super(const []);

  void addGoal(Goal goal) {
    state = [...state, goal];
  }

  void updateGoal(Goal updated) {
    state = [
      for (final g in state) if (g.id == updated.id) updated else g,
    ];
  }

  void removeGoal(String id) {
    state = state.where((g) => g.id != id).toList(growable: false);
  }

  void setLinkedAlarm(String goalId, String? alarmId) {
    state = [
      for (final g in state)
        if (g.id == goalId) g.copyWith(linkedAlarmId: alarmId) else g,
    ];
  }
}

/// İşlemlere göre varlık bazında kalan miktar (alış - satış).
/// Gram altın / bilezik için ayar bazlı: (gramAltin, '', carat24) vb. Diğer varlıklar için purity null.
final remainingAmountPerAssetProvider =
    Provider<Map<_AssetKey, double>>((ref) {
  final transactions = ref.watch(transactionsProvider);
  final map = <_AssetKey, double>{};
  for (final tx in transactions) {
    final purity = (tx.assetType == AssetType.gramAltin ||
            tx.assetType == AssetType.bilezik22)
        ? tx.goldPurity
        : null;
    final key = (tx.assetType, tx.customAssetId ?? '', purity);
    final delta = tx.direction == TransactionDirection.buy ? tx.amount : -tx.amount;
    map[key] = (map[key] ?? 0) + delta;
  }
  return map;
});

/// Tek bir hedef için ilerleme: mevcut değer, hedef, yüzde, kalan.
class GoalProgress {
  const GoalProgress({
    required this.current,
    required this.target,
    required this.percent,
    required this.remaining,
    required this.displayUnit,
  });

  final double current;
  final double target;
  final double percent;
  final double remaining;
  final String displayUnit;
}

/// Tüm hedeflerin ilerleme verisi.
final goalsWithProgressProvider = Provider<List<(Goal, GoalProgress)>>((ref) {
  final goals = ref.watch(goalsProvider);
  final remaining = ref.watch(remainingAmountPerAssetProvider);
  final summary = ref.watch(portfolioSummaryProvider);

  return goals.map((g) {
    GoalProgress progress;
    if (g.type == GoalType.assetAmount && g.assetType != null && g.targetAmount != null) {
      double current;
      final at = g.assetType!;
      final cid = g.customAssetId ?? '';
      if ((at == AssetType.gramAltin || at == AssetType.bilezik22) && g.goldPurity != null) {
        current = remaining[(at, cid, g.goldPurity)] ?? 0;
      } else if (at == AssetType.gramAltin || at == AssetType.bilezik22) {
        current = 0;
        for (final entry in remaining.entries) {
          if (entry.key.$1 == at && entry.key.$2 == cid) {
            current += entry.value;
          }
        }
      } else {
        current = remaining[(at, cid, null)] ?? 0;
      }
      final target = g.targetAmount!;
      final percent = target > 0 ? (current / target).clamp(0.0, 1.0) * 100 : 0.0;
      final remainingVal = (target - current).clamp(0.0, double.infinity);
      progress = GoalProgress(
        current: current,
        target: target,
        percent: percent,
        remaining: remainingVal,
        displayUnit: _unitLabel(at),
      );
    } else if (g.type == GoalType.profit && g.targetProfitTl != null) {
      final current = summary.totalProfitLoss;
      final target = g.targetProfitTl!;
      final percent = target > 0 ? (current / target).clamp(0.0, 1.0) * 100 : 0.0;
      final remainingVal = (target - current).clamp(0.0, double.infinity);
      progress = GoalProgress(
        current: current,
        target: target,
        percent: percent,
        remaining: remainingVal,
        displayUnit: '₺',
      );
    } else {
      progress = const GoalProgress(
        current: 0,
        target: 1,
        percent: 0,
        remaining: 1,
        displayUnit: '',
      );
    }
    return (g, progress);
  }).toList();
});

String _unitLabel(AssetType type) {
  switch (type) {
    case AssetType.gramAltin:
    case AssetType.bilezik22:
    case AssetType.gumus:
    case AssetType.platin:
    case AssetType.paladyum:
      return 'gr';
    case AssetType.ceyrek:
    case AssetType.yarim:
    case AssetType.tam:
    case AssetType.cumhuriyet:
      return 'adet';
    case AssetType.onsAltin:
      return 'ons';
    case AssetType.usd:
      return 'USD';
    case AssetType.eur:
      return 'EUR';
    case AssetType.btc:
      return 'BTC';
    case AssetType.eth:
      return 'ETH';
    case AssetType.otherCrypto:
    case AssetType.stock:
      return '';
  }
}
