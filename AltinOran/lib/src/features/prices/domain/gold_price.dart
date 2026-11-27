import 'package:flutter/foundation.dart';

enum PriceRegion { turkey, usa }

/// Kullanıcının görmek istediği fiyat kaynağı.
/// İlk sürümde görsel/etiket amaçlı; ileride gerçek borsa veri
/// sağlayıcıları ile eşlenecek.
enum PriceSource {
  kapalicarsi,
  bankalar,
  kitco,
  comex,
  bloomberg,
}

enum PriceTrend { up, down, flat }

@immutable
class GoldPrice {
  const GoldPrice({
    required this.region,
    required this.pricePerGram,
    required this.pricePerOunce,
    required this.lastUpdated,
    this.source,
  });

  final PriceRegion region;
  final double pricePerGram;
  final double pricePerOunce;
  final DateTime lastUpdated;
  final String? source;
}

@immutable
class GoldPriceState {
  const GoldPriceState({
    required this.isLoading,
    this.price,
    this.previousPrice,
    this.errorMessage,
  });

  final bool isLoading;
  final GoldPrice? price;
  final GoldPrice? previousPrice;
  final String? errorMessage;

  PriceTrend get trend {
    if (price == null || previousPrice == null) return PriceTrend.flat;
    final current = price!.pricePerGram;
    final previous = previousPrice!.pricePerGram;
    if (current > previous) return PriceTrend.up;
    if (current < previous) return PriceTrend.down;
    return PriceTrend.flat;
  }

  GoldPriceState copyWith({
    bool? isLoading,
    GoldPrice? price,
    GoldPrice? previousPrice,
    String? errorMessage,
  }) {
    return GoldPriceState(
      isLoading: isLoading ?? this.isLoading,
      price: price ?? this.price,
      previousPrice: previousPrice ?? this.previousPrice,
      errorMessage: errorMessage,
    );
  }

  static GoldPriceState initial() =>
      const GoldPriceState(isLoading: false, price: null, previousPrice: null);
}

