import 'package:flutter/foundation.dart';

/// Fiyat alarmının ne zaman tetikleneceğini belirtir.
enum AlarmDirection {
  /// Fiyat hedef seviyenin ÜZERİNE çıkarsa.
  above,

  /// Fiyat hedef seviyenin ALTINA düşerse.
  below,
}

@immutable
class PriceAlarm {
  const PriceAlarm({
    required this.id,
    required this.assetId,
    required this.assetName,
    required this.direction,
    required this.targetPrice,
    required this.createdAt,
    this.isActive = true,
    this.hasTriggered = false,
    this.lastTriggeredPrice,
    this.goalId,
  });

  /// Varlığa özel benzersiz alarm kimliği.
  final String id;

  /// Alarmın bağlı olduğu varlık (RateItem / SupportedAsset id'si).
  final String assetId;

  /// Kullanıcıya gösterilecek varlık adı.
  final String assetName;

  final AlarmDirection direction;

  /// Hedef fiyat (TL cinsinden).
  final double targetPrice;

  /// Alarm şu an aktif mi?
  final bool isActive;

  /// Alarm daha önce tetiklendi mi? (liste gösterimi için; tekrar tetiklemeyi lastTriggeredPrice ile yönetiyoruz)
  final bool hasTriggered;

  /// Son tetiklemede fiyat (tekrar tetikleme için hysteresis: hedefin diğer tarafına geçince sıfırlanır).
  final double? lastTriggeredPrice;

  final DateTime createdAt;

  /// Hedefler ekranından eklenen alarmlar için ilgili hedef id'si (bildirimde "Hedefin X için" gösterilir).
  final String? goalId;

  PriceAlarm copyWith({
    AlarmDirection? direction,
    double? targetPrice,
    bool? isActive,
    bool? hasTriggered,
    double? lastTriggeredPrice,
    bool clearLastTriggeredPrice = false,
    String? goalId,
  }) {
    return PriceAlarm(
      id: id,
      assetId: assetId,
      assetName: assetName,
      direction: direction ?? this.direction,
      targetPrice: targetPrice ?? this.targetPrice,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      hasTriggered: hasTriggered ?? this.hasTriggered,
      lastTriggeredPrice: clearLastTriggeredPrice ? null : (lastTriggeredPrice ?? this.lastTriggeredPrice),
      goalId: goalId ?? this.goalId,
    );
  }
}

