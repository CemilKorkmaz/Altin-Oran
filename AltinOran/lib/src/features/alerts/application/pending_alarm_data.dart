import 'package:flutter/foundation.dart';

import '../domain/price_alarm.dart';

/// Uygulama bildirimden açıldığında gösterilecek alarm bilgisi (kalıcı depodan okunur).
@immutable
class PendingAlarmData {
  const PendingAlarmData({
    required this.alarmId,
    required this.assetName,
    required this.targetPrice,
    required this.direction,
    this.goalTitle,
  });

  final String alarmId;
  final String assetName;
  final double targetPrice;
  final AlarmDirection direction;
  final String? goalTitle;
}
