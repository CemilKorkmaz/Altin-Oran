import 'package:flutter/foundation.dart';

import '../../transactions/domain/investment_transaction.dart';

/// Hedef türü: varlık miktarı veya kâr hedefi.
enum GoalType {
  /// Belirli bir varlığa ulaşılması istenen miktar (gram, adet, USD, BTC vb.).
  assetAmount,

  /// Toplam portföy kârının ulaşılması istenen TL tutarı.
  profit,
}

@immutable
class Goal {
  const Goal({
    required this.id,
    required this.type,
    this.title,
    this.assetType,
    this.goldPurity,
    this.customAssetId,
    this.targetAmount,
    this.targetProfitTl,
    this.linkedAlarmId,
    required this.createdAt,
  }) : assert(
         type == GoalType.assetAmount
             ? (assetType != null && targetAmount != null && targetAmount > 0)
             : (targetProfitTl != null && targetProfitTl > 0),
         'assetAmount için assetType ve targetAmount; profit için targetProfitTl gerekli',
       );

  final String id;
  final GoalType type;

  /// Kısa isim (örn. "50 gr altın birikimi"). Boşsa tür + hedeften türetilir.
  final String? title;

  /// Sadece [GoalType.assetAmount] için: hedef varlık türü.
  final AssetType? assetType;

  /// Sadece gram altın / bilezik için: belirli ayar (24/22/18/14). null = gram bazında toplam (tüm ayarlar).
  final GoldPurity? goldPurity;

  /// otherCrypto vb. için katalog kimliği (örn. crypto_sol).
  final String? customAssetId;

  /// Sadece [GoalType.assetAmount] için: hedef miktar (gram, adet, birim).
  final double? targetAmount;

  /// Sadece [GoalType.profit] için: hedef kâr (TL).
  final double? targetProfitTl;

  /// Bu hedefe bağlı fiyat alarmı (varsa). Bildirimde "Hedefin X için uygun fiyat" gösterilir.
  final String? linkedAlarmId;

  final DateTime createdAt;

  Goal copyWith({
    String? title,
    AssetType? assetType,
    GoldPurity? goldPurity,
    String? customAssetId,
    double? targetAmount,
    double? targetProfitTl,
    String? linkedAlarmId,
  }) {
    return Goal(
      id: id,
      type: type,
      title: title ?? this.title,
      assetType: assetType ?? this.assetType,
      goldPurity: goldPurity ?? this.goldPurity,
      customAssetId: customAssetId ?? this.customAssetId,
      targetAmount: targetAmount ?? this.targetAmount,
      targetProfitTl: targetProfitTl ?? this.targetProfitTl,
      linkedAlarmId: linkedAlarmId ?? this.linkedAlarmId,
      createdAt: createdAt,
    );
  }
}
