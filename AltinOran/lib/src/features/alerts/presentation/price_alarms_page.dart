import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatting.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../application/price_alarm_providers.dart';
import '../domain/price_alarm.dart';

class PriceAlarmsPage extends ConsumerWidget {
  const PriceAlarmsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarms = ref.watch(priceAlarmsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fiyat Alarmlarım'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: alarms.isEmpty
              ? const EmptyStateView(
                  icon: Icons.notifications_off_rounded,
                  title: 'Henüz fiyat alarmı yok',
                  description: 'Hadi bakalım, Kurlar sayfasındaki bir varlık kartından "Alarm Oluştur" ile istediğin fiyata düşünce veya çıkınca bildirim alabilirsin.',
                )
              : ListView.separated(
                  itemCount: alarms.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final alarm = alarms[index];
                    final isActive = alarm.isActive && !alarm.hasTriggered;
                    final statusText = isActive
                        ? 'Aktif'
                        : (alarm.hasTriggered ? 'Tetiklendi' : 'Pasif');
                    final statusColor = isActive
                        ? Colors.green
                        : (alarm.hasTriggered ? Colors.orange : Colors.grey);
                    final dirText =
                        alarm.direction == AlarmDirection.above
                            ? 'üzerine çıkarsa'
                            : 'altına düşerse';

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFE4E4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active_rounded,
                                size: 22,
                                color: Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          alarm.assetName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          color:
                                              statusColor.withOpacity(0.12),
                                        ),
                                        child: Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Fiyat ${dirText} ₺${formatMoney(alarm.targetPrice)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Oluşturulma: ${_formatDateTime(alarm.createdAt)}',
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          _openEditAlarmSheet(
                                              context, ref, alarm);
                                        },
                                        icon: const Icon(
                                          Icons.edit_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Düzenle'),
                                      ),
                                      const SizedBox(width: 4),
                                      TextButton.icon(
                                        onPressed: () {
                                          ref
                                              .read(priceAlarmsProvider
                                                  .notifier)
                                              .removeAlarm(alarm.id);
                                        },
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 18,
                                        ),
                                        label: const Text('Sil'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} $h:$m';
}

void _openEditAlarmSheet(
  BuildContext context,
  WidgetRef ref,
  PriceAlarm alarm,
) {
  final theme = Theme.of(context);
  final controller = TextEditingController(
    text: formatMoney(alarm.targetPrice),
  );
  AlarmDirection direction = alarm.direction;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Alarmı düzenle',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  alarm.assetName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Koşul',
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('ÜZERİNE çıkarsa'),
                      selected: direction == AlarmDirection.above,
                      onSelected: (_) {
                        setModalState(() {
                          direction = AlarmDirection.above;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ALTINA düşerse'),
                      selected: direction == AlarmDirection.below,
                      onSelected: (_) {
                        setModalState(() {
                          direction = AlarmDirection.below;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Hedef fiyat (₺)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final text =
                          controller.text.replaceAll(',', '.').trim();
                      final value = double.tryParse(text);
                      if (value == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Geçerli bir hedef fiyat gir.'),
                          ),
                        );
                        return;
                      }
                      final updated = alarm.copyWith(
                        direction: direction,
                        targetPrice: value,
                        isActive: true,
                        hasTriggered: false,
                      );
                      ref
                          .read(priceAlarmsProvider.notifier)
                          .updateAlarm(updated);
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${alarm.assetName} için alarm güncellendi.',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Kaydet'),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

