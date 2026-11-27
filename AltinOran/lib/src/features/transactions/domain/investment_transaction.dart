import 'package:flutter/foundation.dart';

import '../../prices/domain/gold_price.dart';

/// Desteklenen varlık türleri.
enum AssetType {
  gramAltin,
  ceyrek,
  yarim,
  tam,
  cumhuriyet,
  bilezik22,
  onsAltin,
  gumus,
  platin,
  paladyum,
  usd,
  eur,
  btc,
  eth,
  otherCrypto,
  stock,
}

/// Altın ayarı (ayar / saflık).
enum GoldPurity {
  carat24,
  carat22,
  carat18,
  carat14,
}

/// İşlemin alış mı satış mı olduğunu belirtir.
enum TransactionDirection {
  buy,
  sell,
}

/// İşlemin hangi kanal üzerinden yapıldığını belirtir.
enum PurchaseChannel {
  kuyumcuMagaza,
  kuyumcuOnline,
  bankaSube,
  bankaMobil,
  dovizBurosu,
  borsaViop,
  onlineAltinPlatformu,
  kriptoBorsasi,
  aileArkadas,
  isverenPrimIkramiye,
  diger,
}

@immutable
class InvestmentTransaction {
  const InvestmentTransaction({
    required this.id,
    required this.assetType,
    required this.amount,
    required this.unitPrice,
    required this.dateTime,
    required this.purchaseChannel,
    this.direction = TransactionDirection.buy,
    this.priceSource,
    this.isManualPrice = false,
    this.goldPurity,
    this.note,
    this.customAssetId,
  });

  final String id;
  final AssetType assetType;

  /// Katalog varlık kimliği (örn. crypto_sol). otherCrypto için hangi coin olduğunu belirtir.
  final String? customAssetId;

  /// İşlemde alınan/satılan miktar.
  final double amount;

  /// İşlemin birim fiyatı (alış veya satış fiyatı).
  final double unitPrice;

  /// İşlemin gerçekleştiği tarih-saat.
  final DateTime dateTime;

  final PurchaseChannel purchaseChannel;

  /// İşlemin yönü (alış / satış).
  final TransactionDirection direction;

  /// Fiyatın otomatik geldiği kaynak. Manuel girildiyse null olabilir.
  final PriceSource? priceSource;

  /// Fiyatın manuel mi yoksa kaynaktan mı geldiğini belirtir.
  final bool isManualPrice;

  /// Altın işlemleri için ayar bilgisi (opsiyonel).
  final GoldPurity? goldPurity;

  final String? note;

  /// İşlemin toplam tutarı (mutlak değer).
  double get totalValue => amount * unitPrice;

  /// Altına çevrilebilir varlıklar için yaklaşık gram karşılık.
  /// Diğer varlık türleri (kripto, hisse vb.) için 0 döner.
  double get goldEquivalentGrams {
    switch (assetType) {
      case AssetType.gramAltin:
        return amount;
      case AssetType.bilezik22:
        return amount;
      case AssetType.onsAltin:
        // Troy onsu -> gram. 1 ons ≈ 31.1034768 gr.
        return amount * 31.1034768;
      case AssetType.ceyrek:
        return amount * 1.75;
      case AssetType.yarim:
        return amount * 3.5;
      case AssetType.tam:
        return amount * 7.0;
      case AssetType.cumhuriyet:
        return amount * 7.216;
      default:
        return 0;
    }
  }
}

