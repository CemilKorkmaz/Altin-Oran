import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/domain/price_alarm.dart';
import '../../rates/presentation/rates_page.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../application/goals_providers.dart';
import '../domain/goal.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkCompletedGoals(context, ref));
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(goalsWithProgressProvider);
    ref.listen(goalsWithProgressProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkCompletedGoals(context, ref));
    });

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hedefler'),
        ),
        body: list.isEmpty
            ? _EmptyGoalsView(
                onAddGoal: () => _showAddGoalSheet(context, ref),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final (goal, progress) = list[index];
                  return _GoalCard(
                    goal: goal,
                    progress: progress,
                    onAddAlarm: () => _showAddAlarmForGoal(context, ref, goal),
                    onDelete: () {
                      ref.read(goalsProvider.notifier).removeGoal(goal.id);
                    },
                  );
                },
              ),
        floatingActionButton: list.isEmpty ? null : FloatingActionButton.extended(
          onPressed: () => _showAddGoalSheet(context, ref),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Hedef Ekle'),
        ),
      ),
    );
  }
}

void _checkCompletedGoals(BuildContext context, WidgetRef ref) {
  final list = ref.read(goalsWithProgressProvider);
  final shown = ref.read(completedGoalCelebrationShownProvider);
  final newlyCompleted = list.where((e) {
    final (goal, progress) = e;
    return progress.percent >= 100 && !shown.contains(goal.id);
  }).toList();
  if (newlyCompleted.isEmpty || !context.mounted) return;
  final (goal, _) = newlyCompleted.first;
  final title = goal.title ?? _goalTitle(goal);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.celebration_rounded, color: Theme.of(ctx).colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          const Expanded(child: Text('Hedef tamamlandı!')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tebrikler, bu hedefe ulaştın. Yeni hedefler ekleyebilir veya mevcut hedeflerini takip etmeye devam edebilirsin.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Kapat'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.of(ctx).pop(),
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: const Text('Harika!'),
        ),
      ],
    ),
  ).then((_) {
    ref.read(completedGoalCelebrationShownProvider.notifier).update((s) => s..add(goal.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.flag_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Hedef tamamlandı: $title')),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    _checkCompletedGoals(context, ref);
  });
}

class _EmptyGoalsView extends StatelessWidget {
  const _EmptyGoalsView({required this.onAddGoal});

  final VoidCallback onAddGoal;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.flag_rounded,
      title: 'Henüz hedef yok',
      description: 'Kendinize bir hedef belirleyin, ilerlemenizi adım adım takip edin.',
      actionLabel: 'Hedef Ekle',
      onAction: onAddGoal,
    );
  }
}

class _GoalCard extends ConsumerWidget {
  const _GoalCard({
    required this.goal,
    required this.progress,
    required this.onAddAlarm,
    required this.onDelete,
  });

  final Goal goal;
  final GoalProgress progress;
  final VoidCallback onAddAlarm;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = goal.title ?? _goalTitle(goal);
    final isAsset = goal.type == GoalType.assetAmount;
    final percent = progress.percent.clamp(0.0, 100.0);
    final isComplete = percent >= 100;
    final alarms = ref.watch(priceAlarmsProvider);
    final linkedAlarm = goal.linkedAlarmId != null
        ? alarms.where((a) => a.id == goal.linkedAlarmId).firstOrNull
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAsset
                        ? theme.colorScheme.primaryContainer.withOpacity(0.6)
                        : const Color(0xFF42866B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isAsset ? 'Varlık hedefi' : 'Kâr hedefi',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isComplete) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF42866B).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: const Color(0xFF42866B)),
                        const SizedBox(width: 4),
                        Text(
                          'Tamamlandı',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF42866B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Hedefi sil'),
                        content: const Text(
                          'Bu hedefi silmek istediğine emin misin? Bağlı alarm silinmez.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('İptal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onDelete();
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isComplete ? 1.0 : (percent / 100),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isComplete ? const Color(0xFF42866B) : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.current.toStringAsFixed(progress.displayUnit == '₺' ? 0 : 2)} / ${progress.target.toStringAsFixed(progress.displayUnit == '₺' ? 0 : 2)} ${progress.displayUnit}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '%${percent.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (!isComplete && progress.remaining > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Kalan: ${progress.remaining.toStringAsFixed(progress.displayUnit == '₺' ? 0 : 2)} ${progress.displayUnit}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
            if (isAsset && goal.assetType != null) ...[
              const SizedBox(height: 12),
              if (linkedAlarm != null)
                Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Alarm: ₺${formatMoney(linkedAlarm.targetPrice)} ${linkedAlarm.direction == AlarmDirection.below ? 'altına' : 'üstüne'}',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: onAddAlarm,
                  icon: const Icon(Icons.add_alert_rounded, size: 18),
                  label: const Text('Fiyat alarmı ekle'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _goalTitle(Goal g) {
  if (g.type == GoalType.profit && g.targetProfitTl != null) {
    return '₺${formatMoney(g.targetProfitTl!)} kâr hedefi';
  }
  if (g.type == GoalType.assetAmount && g.assetType != null && g.targetAmount != null) {
    String label = _assetTypeLabel(g.assetType!);
    if (g.goldPurity != null) {
      label += ' (${_goldPurityLabel(g.goldPurity!)})';
    }
    final unit = _unitLabel(g.assetType!);
    return '$label: ${g.targetAmount!.toStringAsFixed(unit == 'gr' || unit == 'adet' ? 0 : 2)} $unit';
  }
  return 'Hedef';
}

String _goldPurityLabel(GoldPurity p) {
  switch (p) {
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
      return 'Dolar';
    case AssetType.eur:
      return 'Euro';
    case AssetType.btc:
      return 'Bitcoin';
    case AssetType.eth:
      return 'Ethereum';
    case AssetType.otherCrypto:
      return 'Kripto';
    case AssetType.stock:
      return 'Hisse / Fon';
  }
}

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

bool _isGoldGramOrBilezik(AssetType? a) {
  return a == AssetType.gramAltin || a == AssetType.bilezik22;
}

Future<void> _showAddGoalSheet(BuildContext context, WidgetRef ref) async {
  GoalType type = GoalType.assetAmount;
  AssetType? assetType = AssetType.gramAltin;
  GoldPurity? goldPurity = null; // null = gram bazında toplam (tüm ayarlar)
  final titleController = TextEditingController();
  final amountController = TextEditingController();
  final profitController = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Yeni hedef',
                      style: Theme.of(ctx).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<GoalType>(
                      segments: const [
                        ButtonSegment(
                          value: GoalType.assetAmount,
                          label: Text('Varlık'),
                          icon: Icon(Icons.stacked_bar_chart_rounded, size: 18),
                        ),
                        ButtonSegment(
                          value: GoalType.profit,
                          label: Text('Kâr'),
                          icon: Icon(Icons.trending_up_rounded, size: 18),
                        ),
                      ],
                      selected: {type},
                      onSelectionChanged: (s) {
                        setModalState(() {
                          type = s.first;
                          if (type == GoalType.profit) {
                            assetType = null;
                            goldPurity = null;
                          } else {
                            assetType = AssetType.gramAltin;
                            goldPurity = null;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (type == GoalType.assetAmount) ...[
                      DropdownButtonFormField<AssetType>(
                        value: assetType,
                        decoration: const InputDecoration(
                          labelText: 'Varlık',
                          border: OutlineInputBorder(),
                        ),
                        items: AssetType.values
                            .map((a) => DropdownMenuItem(
                                  value: a,
                                  child: Text(_assetTypeLabel(a)),
                                ))
                            .toList(),
                        onChanged: (v) => setModalState(() {
                          assetType = v;
                          if (!_isGoldGramOrBilezik(v)) goldPurity = null;
                        }),
                      ),
                      if (_isGoldGramOrBilezik(assetType)) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<GoldPurity?>(
                          value: goldPurity,
                          decoration: const InputDecoration(
                            labelText: 'Gram altın ayarı',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem<GoldPurity?>(
                              value: null,
                              child: Text('Gram bazında toplam (tüm ayarlar)'),
                            ),
                            DropdownMenuItem<GoldPurity?>(
                              value: GoldPurity.carat24,
                              child: Text('24 Ayar'),
                            ),
                            DropdownMenuItem<GoldPurity?>(
                              value: GoldPurity.carat22,
                              child: Text('22 Ayar'),
                            ),
                            DropdownMenuItem<GoldPurity?>(
                              value: GoldPurity.carat18,
                              child: Text('18 Ayar'),
                            ),
                            DropdownMenuItem<GoldPurity?>(
                              value: GoldPurity.carat14,
                              child: Text('14 Ayar'),
                            ),
                          ],
                          onChanged: (v) => setModalState(() => goldPurity = v),
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Hedef miktar (${assetType != null ? _unitLabel(assetType!) : ''})',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: profitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Hedef kâr (₺)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'İsim (isteğe bağlı)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {
                        if (type == GoalType.assetAmount) {
                          final v = double.tryParse(
                              amountController.text.replaceAll(',', '.').trim());
                          if (assetType == null || v == null || v <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Varlık ve hedef miktar girin.')),
                            );
                            return;
                          }
                          final goal = Goal(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            type: type,
                            title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
                            assetType: assetType,
                            goldPurity: _isGoldGramOrBilezik(assetType) ? goldPurity : null,
                            targetAmount: v,
                            createdAt: DateTime.now(),
                          );
                          ref.read(goalsProvider.notifier).addGoal(goal);
                        } else {
                          final v = double.tryParse(
                              profitController.text.replaceAll(',', '.').trim());
                          if (v == null || v <= 0) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Hedef kâr (₺) girin.')),
                            );
                            return;
                          }
                          final goal = Goal(
                            id: DateTime.now().microsecondsSinceEpoch.toString(),
                            type: type,
                            title: titleController.text.trim().isEmpty ? null : titleController.text.trim(),
                            targetProfitTl: v,
                            createdAt: DateTime.now(),
                          );
                          ref.read(goalsProvider.notifier).addGoal(goal);
                        }
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Hedef eklendi.')),
                        );
                      },
                      child: const Text('Oluştur'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showAddAlarmForGoal(BuildContext context, WidgetRef ref, Goal goal) async {
  if (goal.assetType == null) return;
  final rates = ref.read(ratesListProvider);
  RateItem? rate;
  if (goal.customAssetId != null && goal.customAssetId!.isNotEmpty) {
    rate = rates.where((r) => r.id == goal.customAssetId).firstOrNull;
  }
  rate ??= rates.where((r) => r.assetType == goal.assetType).firstOrNull;
  if (rate == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu varlık için Kurlar listesinde fiyat bulunamadı.')),
    );
    return;
  }

  AlarmDirection direction = AlarmDirection.below;
  final controller = TextEditingController();

  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${rate!.name} için fiyat alarmı',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Hedefin için uygun fiyata düşünce veya çıkınca bildirim alırsın.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('ÜZERİNE çıksın'),
                      selected: direction == AlarmDirection.above,
                      onSelected: (_) =>
                          setModalState(() => direction = AlarmDirection.above),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ALTINA düşsün'),
                      selected: direction == AlarmDirection.below,
                      onSelected: (_) =>
                          setModalState(() => direction = AlarmDirection.below),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hedef fiyat (₺)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    final v = double.tryParse(
                        controller.text.replaceAll(',', '.').trim());
                    if (v == null) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir fiyat gir.')),
                      );
                      return;
                    }
                    final alarm = ref.read(priceAlarmsProvider.notifier).addAlarm(
                          assetId: rate!.id,
                          assetName: rate.name,
                          direction: direction,
                          targetPrice: v,
                          goalId: goal.id,
                        );
                    ref.read(goalsProvider.notifier).setLinkedAlarm(goal.id, alarm.id);
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Alarm kaydedildi. ${rate.name} ₺${formatMoney(v)} ${direction == AlarmDirection.below ? "altına" : "üstüne"} düşünce/çıkınca bildirim alacaksın.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_rounded),
                  label: const Text('Alarmı Kaydet'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
