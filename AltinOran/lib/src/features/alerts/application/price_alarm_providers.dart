import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../rates/presentation/rates_page.dart';
import '../domain/price_alarm.dart';
import 'pending_alarm_data.dart';

/// Tüm fiyat alarmlarını tutan provider.
final priceAlarmsProvider =
    StateNotifierProvider<PriceAlarmsNotifier, List<PriceAlarm>>(
  (ref) => PriceAlarmsNotifier(),
);

class PriceAlarmsNotifier extends StateNotifier<List<PriceAlarm>> {
  PriceAlarmsNotifier() : super(const []);

  /// Eklenen alarmı döndürür (hedefe bağlamak için id kullanılabilir).
  PriceAlarm addAlarm({
    required String assetId,
    required String assetName,
    required AlarmDirection direction,
    required double targetPrice,
    String? goalId,
  }) {
    final alarm = PriceAlarm(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      assetId: assetId,
      assetName: assetName,
      direction: direction,
      targetPrice: targetPrice,
      createdAt: DateTime.now(),
      goalId: goalId,
    );
    state = [...state, alarm];
    return alarm;
  }

  void removeAlarm(String id) {
    state = state.where((a) => a.id != id).toList(growable: false);
  }

  void _updateAlarm(PriceAlarm updated) {
    state = [
      for (final a in state) if (a.id == updated.id) updated else a,
    ];
  }

  void updateAlarm(PriceAlarm updated) => _updateAlarm(updated);

  /// Güncel fiyatlara göre alarmları kontrol eder.
  /// Tetiklenen her alarm için [onTriggered] çağrılır.
  /// Aynı alarm, fiyat hedefin diğer tarafına geçip tekrar tetiklenirse yeniden bildirim verir (hysteresis).
  void checkAndTrigger(
    List<RateItem> rates,
    void Function(PriceAlarm alarm, RateItem rate) onTriggered,
  ) {
    if (state.isEmpty) return;
    final byId = {
      for (final r in rates) r.id: r,
    };

    for (final alarm in state) {
      if (!alarm.isActive) continue;
      final rate = byId[alarm.assetId];
      final current = rate?.lastPrice;
      if (current == null) continue;

      switch (alarm.direction) {
        case AlarmDirection.above:
          if (current < alarm.targetPrice) {
            _updateAlarm(alarm.copyWith(clearLastTriggeredPrice: true));
          } else if (alarm.lastTriggeredPrice == null || alarm.lastTriggeredPrice! < alarm.targetPrice) {
            final updated = alarm.copyWith(lastTriggeredPrice: current, hasTriggered: true);
            _updateAlarm(updated);
            onTriggered(updated, rate!);
          }
          break;
        case AlarmDirection.below:
          if (current > alarm.targetPrice) {
            _updateAlarm(alarm.copyWith(clearLastTriggeredPrice: true));
          } else if (alarm.lastTriggeredPrice == null || alarm.lastTriggeredPrice! > alarm.targetPrice) {
            final updated = alarm.copyWith(lastTriggeredPrice: current, hasTriggered: true);
            _updateAlarm(updated);
            onTriggered(updated, rate!);
          }
          break;
      }
    }
  }
}

/// Uygulama bildirimden açıldığında gösterilecek alarm (banner + "Alarmı kaldır").
final pendingAlarmProvider = StateProvider<PendingAlarmData?>((ref) => null);
