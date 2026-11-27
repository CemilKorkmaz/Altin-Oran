import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state_view.dart';
import '../../transactions/domain/investment_transaction.dart';
import '../../prices/application/gold_price_providers.dart';
import '../../prices/application/usd_try_rate_providers.dart';
import '../../prices/application/eur_try_rate_providers.dart';
import '../application/rates_prices_cache.dart';
import '../../prices/domain/supported_asset.dart';
import '../../prices/domain/gold_price.dart';
import '../../alerts/application/notification_service.dart';
import '../../alerts/application/price_alarm_providers.dart';
import '../../alerts/domain/price_alarm.dart';
import '../../alerts/presentation/price_alarms_page.dart';
import '../../alerts/presentation/alarm_notification_banner.dart';
import '../../goals/application/goals_providers.dart';
import '../../settings/application/settings_providers.dart';
import '../../stats/presentation/stats_page.dart';
import '../../../core/formatting.dart';

enum RateCategory { all, currency, metals, coins, favorites }

enum RateType { metal, bank, coin }

/// Kurlar arama kutusu için sorgu.
final ratesSearchQueryProvider = StateProvider<String?>((ref) => null);

class RateItem {
  const RateItem({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.buyPrice,
    this.sellPrice,
    this.lastPrice,
    this.changePercent,
    this.spread,
    this.spreadPercent,
    this.subtitle,
    this.assetType,
    this.goldPurity,
    this.dailyLow,
    this.dailyHigh,
    this.closingPrice,
    this.lastUpdated,
  });

  final String id;
  final String name;
  final String code;
  final RateType type;

  final double? buyPrice;
  final double? sellPrice;
  final double? lastPrice;
  final double? changePercent;
  final double? spread;
  final double? spreadPercent;
  final String? subtitle;

  /// Bu fiyatın ait olduğu varlık (ör. gram altın, ons altın, BTC).
  final AssetType? assetType;

  /// Altın için ayar bilgisi (varsa).
  final GoldPurity? goldPurity;

  /// Günün en düşük fiyatı (API'den).
  final double? dailyLow;
  /// Günün en yüksek fiyatı (API'den).
  final double? dailyHigh;

  /// Kapanış fiyatı (detay paneli). Yoksa changePercent ile hesaplanır.
  final double? closingPrice;

  /// Son güncelleme zamanı (detay paneli "Son güncelleme" satırı).
  final DateTime? lastUpdated;
}

/// Madenler sekmesinde seçilen metal grubu: null = tümü, 'gold' = altın, 'silver' = gümüş, 'platinum' = platin, 'other' = diğer madenler.
class RatesState {
  const RatesState({
    required this.items,
    required this.favorites,
    required this.category,
    required this.selectedMetalGroup,
    required this.selectedAssetType,
    required this.selectedGoldPurity,
  });

  final List<RateItem> items;
  final Set<String> favorites;
  final RateCategory category;
  final String? selectedMetalGroup;
  final AssetType? selectedAssetType;
  final GoldPurity? selectedGoldPurity;

  RatesState copyWith({
    List<RateItem>? items,
    Set<String>? favorites,
    RateCategory? category,
    String? selectedMetalGroup,
    bool clearSelectedMetalGroup = false,
    AssetType? selectedAssetType,
    bool clearSelectedAssetType = false,
    GoldPurity? selectedGoldPurity,
    bool clearSelectedGoldPurity = false,
  }) {
    return RatesState(
      items: items ?? this.items,
      favorites: favorites ?? this.favorites,
      category: category ?? this.category,
      selectedMetalGroup: clearSelectedMetalGroup ? null : (selectedMetalGroup ?? this.selectedMetalGroup),
      selectedAssetType: clearSelectedAssetType
          ? null
          : (selectedAssetType ?? this.selectedAssetType),
      selectedGoldPurity: clearSelectedGoldPurity
          ? null
          : (selectedGoldPurity ?? this.selectedGoldPurity),
    );
  }

  static RatesState initial() {
    return RatesState(
      items: const [],
      favorites: <String>{},
      category: RateCategory.all,
      selectedMetalGroup: null,
      selectedAssetType: null,
      selectedGoldPurity: null,
    );
  }
}

/// Son kurlar yenileme zamanı (sayfa açılışında throttle için).
final lastRatesRefreshAtProvider = StateProvider<DateTime?>((ref) => null);

/// Kategori sırası: 0=Döviz, 1=Altın, 2=Gümüş, 3=Platin, 4=Diğer maden, 5=Coin.
/// Sadece id prefix'ine göre atanır — araya başka tür girmez.
(int, int) _rateItemCategoryOrder(RateItem item) {
  if (item.id.startsWith('fx_')) return (0, item.id == 'fx_usd_try' ? 0 : 1);
  if (item.type == RateType.coin) return (5, item.id.hashCode);
  // Madenler: id prefix kesin — gold_ sadece altın, metal_ sadece paladyum/rodyum vb.
  if (item.id.startsWith('gold_')) {
    if (item.assetType == AssetType.gramAltin) {
      final p = item.goldPurity ?? GoldPurity.carat24;
      final sub = switch (p) {
        GoldPurity.carat24 => 0,
        GoldPurity.carat22 => 1,
        GoldPurity.carat18 => 2,
        GoldPurity.carat14 => 3,
      };
      return (1, sub);
    }
    const goldOrder = ['gold_ceyrek', 'gold_yarim', 'gold_tam', 'gold_cumhuriyet', 'gold_bilezik22', 'gold_ons'];
    final idx = goldOrder.indexOf(item.id);
    return (1, idx >= 0 ? 10 + idx : 99);
  }
  if (item.id.startsWith('silver_')) return (2, item.id == 'silver_gram' ? 0 : 1);
  if (item.id.startsWith('platinum_')) return (3, item.id == 'platinum_gram' ? 0 : 1);
  if (item.id.startsWith('metal_')) return (4, item.id == 'metal_palladium_gram' ? 0 : 1);
  return (5, 0);
}

/// Katalogdaki varlıkları + banka fiyatlarını Kurlar listesi olarak döndürür.
List<RateItem> _buildRatesListFromCatalog(List<SupportedAsset> assets) {
  final list = <RateItem>[];
  for (final a in assets) {
    list.add(_supportedAssetToRateItem(a));
  }
  // Gram Altın diğer ayarları (gerçek hayatta 22, 18, 14 ayar da işlem görür)
  list.addAll(_gramAltinOtherPurities());
  // Banka fiyatları (Gram 24 ayar için "diğer alış fiyatları" altında gösterilir)
  list.addAll(_bankRateItems);
  return list;
}

/// Gram Altın 22, 18, 14 Ayar kartları (fiyat API'den; şu an sadece katalog).
List<RateItem> _gramAltinOtherPurities() {
  return [
    _gramAltinPurityItem('gold_gram_22', 'Gram Altın (22 Ayar)', GoldPurity.carat22, 'API\'den yüklenecek'),
    _gramAltinPurityItem('gold_gram_18', 'Gram Altın (18 Ayar)', GoldPurity.carat18, null),
    _gramAltinPurityItem('gold_gram_14', 'Gram Altın (14 Ayar)', GoldPurity.carat14, null),
  ];
}

RateItem _gramAltinPurityItem(
  String id,
  String name,
  GoldPurity purity,
  String? subtitle,
) {
  return RateItem(
    id: id,
    name: name,
    code: 'Au',
    type: RateType.metal,
    buyPrice: null,
    sellPrice: null,
    lastPrice: null,
    changePercent: null,
    dailyLow: null,
    dailyHigh: null,
    closingPrice: null,
    subtitle: subtitle,
    assetType: AssetType.gramAltin,
    goldPurity: purity,
  );
}

/// SupportedAsset -> RateItem (fiyatlar API'den doldurulur; katalogda null).
RateItem _supportedAssetToRateItem(SupportedAsset a) {
  final type = a.isCrypto ? RateType.coin : RateType.metal;
  final (AssetType? assetType, GoldPurity? goldPurity) = _assetTypeAndPurityFor(a.id);
  String code = _rateCodeFor(a);
  String name = a.id == 'gold_gram' ? 'Gram Altın (24 Ayar)' : a.name;
  String? subtitle;
  if (a.id == 'gold_gram') subtitle = 'Kapalıçarşı / Banka ort.';
  if (a.id == 'gold_ons') subtitle = 'XAUUSD';
  return RateItem(
    id: a.id,
    name: name,
    code: code,
    type: type,
    buyPrice: null,
    sellPrice: null,
    lastPrice: null,
    changePercent: null,
    dailyLow: null,
    dailyHigh: null,
    closingPrice: null,
    subtitle: subtitle,
    assetType: assetType,
    goldPurity: goldPurity,
  );
}

/// Madenler için periyodik tablo sembolü, coinler için mevcut kod.
String _rateCodeFor(SupportedAsset a) {
  const fxCodes = <String, String>{
    'fx_usd_try': 'USD',
    'fx_eur_try': 'EUR',
  };
  if (fxCodes.containsKey(a.id)) return fxCodes[a.id]!;
  const metalSymbols = <String, String>{
    'gold_gram': 'Au',
    'gold_gram_22': 'Au',
    'gold_gram_18': 'Au',
    'gold_gram_14': 'Au',
    'gold_ceyrek': 'Au',
    'gold_yarim': 'Au',
    'gold_tam': 'Au',
    'gold_cumhuriyet': 'Au',
    'gold_bilezik22': 'Au',
    'gold_ons': 'Au',
    'silver_gram': 'Ag',
    'silver_ons': 'Ag',
    'platinum_gram': 'Pt',
    'platinum_ons': 'Pt',
    'metal_palladium_gram': 'Pd',
    'metal_rhodium': 'Rh',
  };
  if (metalSymbols.containsKey(a.id)) return metalSymbols[a.id]!;
  const codes = <String, String>{
    'crypto_btc': 'BTC',
    'crypto_eth': 'ETH',
    'crypto_bnb': 'BNB',
    'crypto_xrp': 'XRP',
    'crypto_ada': 'ADA',
    'crypto_sol': 'SOL',
    'crypto_doge': 'DOGE',
    'crypto_dot': 'DOT',
    'crypto_avax': 'AVAX',
    'crypto_matic': 'MATIC',
    'crypto_ltc': 'LTC',
    'crypto_link': 'LINK',
    'crypto_uni': 'UNI',
    'crypto_atom': 'ATOM',
    'crypto_xlm': 'XLM',
    'crypto_bch': 'BCH',
    'crypto_etc': 'ETC',
    'crypto_xmr': 'XMR',
    'crypto_trx': 'TRX',
    'crypto_fil': 'FIL',
  };
  if (codes.containsKey(a.id)) return codes[a.id]!;
  if (a.symbol != null) {
    String s = a.symbol!.replaceAll('USDT', '').replaceAll('USD', '');
    if (s.length > 6) s = s.substring(0, 6);
    return s.toUpperCase();
  }
  return a.id.length > 6 ? a.id.substring(0, 6).toUpperCase() : a.id.toUpperCase();
}

/// Maden ve coin için kart rengi (marka / element rengi).
Color _assetColor(String id, RateType type) {
  const fxColors = <String, Color>{
    'fx_usd_try': Color(0xFF2E7D32), // yeşil dolar
    'fx_eur_try': Color(0xFF1565C0), // mavi euro
  };
  if (fxColors.containsKey(id)) return fxColors[id]!;
  if (type == RateType.metal) {
    const metalColors = <String, Color>{
      'gold_gram': Color(0xFFD4AF37),
      'gold_gram_22': Color(0xFFD4AF37),
      'gold_gram_18': Color(0xFFD4AF37),
      'gold_gram_14': Color(0xFFD4AF37),
      'gold_ceyrek': Color(0xFFD4AF37),
      'gold_yarim': Color(0xFFD4AF37),
      'gold_tam': Color(0xFFD4AF37),
      'gold_cumhuriyet': Color(0xFFD4AF37),
      'gold_bilezik22': Color(0xFFD4AF37),
      'gold_ons': Color(0xFFD4AF37),
      'silver_gram': Color(0xFFA8A9AD),
      'silver_ons': Color(0xFFA8A9AD),
      'platinum_gram': Color(0xFFE5E4E2),
      'platinum_ons': Color(0xFFE5E4E2),
      'metal_palladium_gram': Color(0xFFB4B4B4),
      'metal_rhodium': Color(0xFF8B8B8B),
    };
    return metalColors[id] ?? const Color(0xFFD4AF37);
  }
  if (type == RateType.coin) {
    const coinColors = <String, Color>{
      'crypto_btc': Color(0xFFF7931A),
      'crypto_eth': Color(0xFF627EEA),
      'crypto_bnb': Color(0xFFF3BA2F),
      'crypto_xrp': Color(0xFF00AAE4),
      'crypto_ada': Color(0xFF0033AD),
      'crypto_sol': Color(0xFF00FFA3),
      'crypto_doge': Color(0xFFC2A633),
      'crypto_dot': Color(0xFFE6007A),
      'crypto_avax': Color(0xFFE84142),
      'crypto_matic': Color(0xFF8247E5),
      'crypto_ltc': Color(0xFFBFBBBB),
      'crypto_link': Color(0xFF2A5ADA),
      'crypto_uni': Color(0xFFFF007A),
      'crypto_atom': Color(0xFF2E3148),
      'crypto_xlm': Color(0xFF000000),
      'crypto_bch': Color(0xFF8DC351),
      'crypto_etc': Color(0xFF328332),
      'crypto_xmr': Color(0xFFFF6600),
      'crypto_trx': Color(0xFFFF0013),
      'crypto_fil': Color(0xFF0090FF),
    };
    return coinColors[id] ?? const Color(0xFFF59E0B);
  }
  return const Color(0xFFD4AF37);
}

(AssetType?, GoldPurity?) _assetTypeAndPurityFor(String id) {
  switch (id) {
    case 'fx_usd_try': return (AssetType.usd, null);
    case 'fx_eur_try': return (AssetType.eur, null);
    case 'gold_gram': return (AssetType.gramAltin, GoldPurity.carat24);
    case 'gold_ceyrek': return (AssetType.ceyrek, null);
    case 'gold_yarim': return (AssetType.yarim, null);
    case 'gold_tam': return (AssetType.tam, null);
    case 'gold_cumhuriyet': return (AssetType.cumhuriyet, null);
    case 'gold_bilezik22': return (AssetType.bilezik22, GoldPurity.carat22);
    case 'gold_ons': return (AssetType.onsAltin, GoldPurity.carat24);
    case 'silver_gram':
    case 'silver_ons': return (AssetType.gumus, null);
    case 'platinum_gram':
    case 'platinum_ons': return (AssetType.platin, null);
    case 'metal_palladium_gram': return (AssetType.paladyum, null);
    case 'metal_rhodium': return (AssetType.platin, null); // rodyum için platin yakın
    case 'crypto_btc': return (AssetType.btc, null);
    case 'crypto_eth': return (AssetType.eth, null);
    default:
      if (id.startsWith('crypto_')) return (AssetType.otherCrypto, null);
      return (AssetType.gramAltin, null);
  }
}

List<RateItem> get _bankRateItems => [
  RateItem(
    id: 'bank-dunyakatilim',
    name: 'Dünya Katılım',
    code: 'DUNYA',
    type: RateType.bank,
    buyPrice: null,
    sellPrice: null,
    lastPrice: null,
    subtitle: 'API\'den yüklenecek',
    assetType: AssetType.gramAltin,
    goldPurity: GoldPurity.carat24,
  ),
  RateItem(
    id: 'bank-kuveytturk',
    name: 'Kuveyt Türk',
    code: 'KUVTURK',
    type: RateType.bank,
    buyPrice: null,
    sellPrice: null,
    lastPrice: null,
    subtitle: 'API\'den yüklenecek',
    assetType: AssetType.gramAltin,
    goldPurity: GoldPurity.carat24,
  ),
];

/// item.id → Bigpara API byKey anahtarı (altın türleri, gümüş, platin).
String? _bigparaKeyForItemId(String id) {
  switch (id) {
    case 'gold_gram': return 'gram_altin';
    case 'gold_ceyrek': return 'ceyrek';
    case 'gold_yarim': return 'yarim';
    case 'gold_tam': return 'tam';
    case 'gold_cumhuriyet': return 'cumhuriyet';
    case 'gold_bilezik22': return 'bilezik_22';
    case 'gold_ons': return 'ons';
    case 'gold_gram_22': return 'gram_22';
    case 'gold_gram_18': return 'gram_18';
    case 'gold_gram_14': return 'gram_14';
    case 'silver_gram': return 'silver_gram';
    case 'silver_ons': return 'silver_ons';
    case 'platinum_gram': return 'platinum_gram';
    case 'platinum_ons': return 'platinum_ons';
    default: return null;
  }
}

double? _numFromBigpara(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

/// Kurlar sayfasında gösterilecek tüm kartlar: katalog + API fiyatları (altın, döviz, maden, kripto) ve günlük düşük/yüksek.
final ratesListProvider = Provider<List<RateItem>>((ref) {
  final assets = ref.watch(allSupportedAssetsProvider);
  final baseList = _buildRatesListFromCatalog(assets);
  final usdRate = ref.watch(usdTryRateProvider).rate;
  final eurRate = ref.watch(eurTryRateProvider).rate;
  final cache = ref.watch(ratesPricesCacheProvider);
  final bigparaByKey = ref.watch(bigparaByKeyProvider);
  final goldState = ref.watch(goldPriceProvider);

  return [
    for (final item in baseList) _mergeItemWithApi(item, usdRate, eurRate, cache, bigparaByKey, goldState),
  ];
});

RateItem _mergeItemWithApi(
  RateItem item,
  double? usdRate,
  double? eurRate,
  Map<String, CachedRateData> cache,
  Map<String, Map<String, dynamic>>? bigparaByKey,
  GoldPriceState goldState,
) {
  // Bigpara'dan gelen tüm altın/gümüş/platin türleri
  final bpKey = _bigparaKeyForItemId(item.id);
  if (bpKey != null) {
    if (bigparaByKey != null) {
      final data = bigparaByKey[bpKey];
      if (data != null) {
        final alis = _numFromBigpara(data['alis']);
        final satis = _numFromBigpara(data['satis']);
        final changePercent = _numFromBigpara(data['changePercent']);
        final lastPrice = satis ?? alis ?? (alis != null && satis != null ? (alis + satis) / 2 : null);
        if (lastPrice != null && lastPrice > 0) {
          return RateItem(
            id: item.id,
            name: item.name,
            code: item.code,
            type: item.type,
            buyPrice: alis,
            sellPrice: satis,
            lastPrice: lastPrice,
            changePercent: changePercent ?? item.changePercent,
            dailyLow: item.dailyLow,
            dailyHigh: item.dailyHigh,
            subtitle: 'Bigpara',
            assetType: item.assetType,
            goldPurity: item.goldPurity,
            closingPrice: item.closingPrice,
          );
        }
      }
    }
    final gold = goldState.price;
    if (item.id == 'gold_gram' && gold != null && gold.region == PriceRegion.turkey) {
      return RateItem(
        id: item.id, name: item.name, code: item.code, type: item.type,
        lastPrice: gold.pricePerGram, lastUpdated: gold.lastUpdated,
        subtitle: 'Referans fiyat', assetType: item.assetType, goldPurity: item.goldPurity,
      );
    }
    final cachedMetal = cache[item.id];
    if (cachedMetal != null) {
      return RateItem(
        id: item.id, name: item.name, code: item.code, type: item.type,
        lastPrice: cachedMetal.lastPrice, lastUpdated: cachedMetal.lastUpdated,
        subtitle: 'Referans fiyat', assetType: item.assetType, goldPurity: item.goldPurity,
      );
    }
    // Kaynak yoksa tahmini bir değer üretme.
    return RateItem(
      id: item.id,
      name: item.name,
      code: item.code,
      type: item.type,
      buyPrice: null,
      sellPrice: null,
      lastPrice: null,
      changePercent: item.changePercent,
      spread: item.spread,
      spreadPercent: item.spreadPercent,
      subtitle: 'Veri yok',
      assetType: item.assetType,
      goldPurity: item.goldPurity,
      dailyLow: null,
      dailyHigh: null,
      closingPrice: null,
      lastUpdated: item.lastUpdated,
    );
  }

  // Döviz ve cache aşağıda.

  // Döviz: Frankfurter. Kur yoksa veri yok göster.
  if (item.id == 'fx_usd_try') {
    if (usdRate == null) {
      return RateItem(
        id: item.id,
        name: item.name,
        code: item.code,
        type: item.type,
        buyPrice: null,
        sellPrice: null,
        lastPrice: null,
        changePercent: item.changePercent,
        dailyLow: null,
        dailyHigh: null,
        subtitle: 'Veri yüklenemedi',
        assetType: item.assetType,
        goldPurity: item.goldPurity,
      );
    }
    return RateItem(
      id: item.id,
      name: item.name,
      code: item.code,
      type: item.type,
      buyPrice: null,
      sellPrice: null,
      lastPrice: usdRate,
      changePercent: item.changePercent,
      dailyLow: item.dailyLow,
      dailyHigh: item.dailyHigh,
      subtitle: 'Frankfurter · referans kur',
      assetType: item.assetType,
      goldPurity: item.goldPurity,
    );
  }
  if (item.id == 'fx_eur_try') {
    if (eurRate == null) {
      return RateItem(
        id: item.id,
        name: item.name,
        code: item.code,
        type: item.type,
        buyPrice: null,
        sellPrice: null,
        lastPrice: null,
        changePercent: item.changePercent,
        dailyLow: null,
        dailyHigh: null,
        subtitle: 'Veri yüklenemedi',
        assetType: item.assetType,
        goldPurity: item.goldPurity,
      );
    }
    return RateItem(
      id: item.id,
      name: item.name,
      code: item.code,
      type: item.type,
      buyPrice: null,
      sellPrice: null,
      lastPrice: eurRate,
      changePercent: item.changePercent,
      dailyLow: item.dailyLow,
      dailyHigh: item.dailyHigh,
      subtitle: 'Frankfurter · referans kur',
      assetType: item.assetType,
      goldPurity: item.goldPurity,
    );
  }

  // API önbelleğindeki değerler; olmayan alış/satış değerlerini uydurmayız.
  final cached = cache[item.id];
  if (cached != null) {
    return RateItem(
      id: item.id,
      name: item.name,
      code: item.code,
      type: item.type,
      buyPrice: cached.buyPrice,
      sellPrice: cached.sellPrice,
      lastPrice: cached.lastPrice,
      changePercent: cached.changePercent ?? item.changePercent,
      dailyLow: cached.dailyLow ?? item.dailyLow,
      dailyHigh: cached.dailyHigh ?? item.dailyHigh,
      spread: item.spread,
      spreadPercent: item.spreadPercent,
      subtitle: item.subtitle,
      assetType: item.assetType,
      goldPurity: item.goldPurity,
      closingPrice: item.closingPrice,
      lastUpdated: cached.lastUpdated,
    );
  }

  return item;
}

class RatesNotifier extends StateNotifier<RatesState> {
  RatesNotifier() : super(RatesState.initial());

  void setCategory(RateCategory category) {
    state = state.copyWith(category: category);
  }

  void setSelectedMetalGroup(String? group) {
    state = state.copyWith(
      selectedMetalGroup: group,
      clearSelectedAssetType: true,
      clearSelectedGoldPurity: true,
    );
  }

  void setSelectedAssetType(AssetType? type) {
    if (type == null) {
      state = state.copyWith(clearSelectedAssetType: true);
    } else {
      // Ons Altında sadece 24 ayar vardır; 22/18/14 seçiliyse temizle
      final purity = state.selectedGoldPurity;
      final clearPurity = type == AssetType.onsAltin &&
          purity != null &&
          purity != GoldPurity.carat24;
      state = state.copyWith(
        selectedAssetType: type,
        clearSelectedGoldPurity: clearPurity,
      );
    }
  }

  void setSelectedGoldPurity(GoldPurity? purity) {
    if (purity == null) {
      state = state.copyWith(clearSelectedGoldPurity: true);
    } else {
      state = state.copyWith(selectedGoldPurity: purity);
    }
  }

  void toggleFavorite(String id) {
    final newFavs = Set<String>.from(state.favorites);
    if (newFavs.contains(id)) {
      newFavs.remove(id);
    } else {
      newFavs.add(id);
    }
    state = state.copyWith(favorites: newFavs);
  }
}

final ratesProvider =
    StateNotifierProvider<RatesNotifier, RatesState>((ref) {
  return RatesNotifier();
});

class RatesPage extends ConsumerWidget {
  const RatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kurlar sekmesi açıldığında yenile: ilk açılış veya son yenilemeden 60 sn geçtiyse.
    // Throttle hemen başta uygulanır (yenileme bitmeden tekrar tetiklenmesin).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lastAt = ref.read(lastRatesRefreshAtProvider);
      final now = DateTime.now();
      final shouldRefresh = lastAt == null ||
          now.difference(lastAt).inSeconds > 60;
      if (shouldRefresh) {
        ref.read(lastRatesRefreshAtProvider.notifier).state = now;
        ref.read(usdTryRateProvider.notifier).refresh();
        ref.read(eurTryRateProvider.notifier).refresh();
        ref.read(bigparaByKeyProvider.notifier).refresh();
        ref.read(goldPriceProvider.notifier).refresh();
        ref.read(ratesPricesCacheProvider.notifier).refresh();
      }
    });

    final state = ref.watch(ratesProvider);
    final allItems = ref.watch(ratesListProvider);
    final alarmsNotifier = ref.watch(priceAlarmsProvider.notifier);
    final searchQuery = ref.watch(ratesSearchQueryProvider) ?? '';

    // Banka fiyatları ayrı kart olarak değil, ilgili maden kartının içinde
    // ("X fiyat" açıldığında) gösterilir. Ana listede sadece maden ve coin kartları.
    final filteredItems = allItems.where((item) {
      if (item.type == RateType.bank) return false;

      final cat = state.category;
      if (cat == RateCategory.favorites &&
          !state.favorites.contains(item.id)) {
        return false;
      }
      switch (cat) {
        case RateCategory.all:
        case RateCategory.favorites:
          return true;
        case RateCategory.currency:
          return item.id.startsWith('fx_');
        case RateCategory.metals:
          return item.type == RateType.metal && !item.id.startsWith('fx_');
        case RateCategory.coins:
          return item.type == RateType.coin;
      }
    }).where((item) {
      // Metin araması: ad veya kod içinde sorgu geçiyorsa kalsın.
      final q = searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        final name = item.name.toLowerCase();
        final code = item.code.toLowerCase();
        if (!name.contains(q) && !code.contains(q)) return false;
      }
      if (state.category == RateCategory.metals && item.type == RateType.metal) {
        final group = state.selectedMetalGroup;
        if (group != null) {
          if (group == 'gold' && !item.id.startsWith('gold_')) return false;
          if (group == 'silver' && !item.id.startsWith('silver_')) return false;
          if (group == 'platinum' && !item.id.startsWith('platinum_')) return false;
          if (group == 'other' && !item.id.startsWith('metal_')) return false;
        }
        if (state.selectedAssetType != null &&
            item.assetType != state.selectedAssetType) {
          return false;
        }
        if (state.selectedGoldPurity != null &&
            item.goldPurity != state.selectedGoldPurity) {
          return false;
        }
      }
      return true;
    }).toList();

    // Sıralama: Aynı maden türü kesinlikle bir arada — altınlar, gümüşler, platinler, diğer madenler, coinler.
    // Hiçbir varlık türü araya girmesin.
    filteredItems.sort((a, b) {
      final (int catA, int subA) = _rateItemCategoryOrder(a);
      final (int catB, int subB) = _rateItemCategoryOrder(b);
      final c = catA.compareTo(catB);
      if (c != 0) return c;
      final s = subA.compareTo(subB);
      if (s != 0) return s;
      return a.id.compareTo(b.id);
    });

    // Fiyat alarmlarını güncel RateItem listesine göre kontrol et.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider);
      if (!settings.alarmBannerEnabled) return;
      alarmsNotifier.checkAndTrigger(allItems, (alarm, rate) {
        final price = rate.lastPrice;
        if (!context.mounted || price == null) return;
        final goals = ref.read(goalsProvider);
        final goal = alarm.goalId != null ? goals.where((g) => g.id == alarm.goalId).firstOrNull : null;
        AlarmNotificationBanner.show(
          context,
          alarm: alarm,
          rate: rate,
          goalTitle: goal?.title,
          onRemoveAlarm: () => ref.read(priceAlarmsProvider.notifier).removeAlarm(alarm.id),
        );
        NotificationService.showAlarmNotification(alarm: alarm, rate: rate, goalTitle: goal?.title);
      });
    });

    final ratesNotifier = ref.read(ratesProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Scaffold(
        appBar: AppBar(
          centerTitle: false,
          titleSpacing: 16,
          title: const Text('Kurlar'),
          actions: [
            IconButton(
              onPressed: () {
                final current = state.category;
                ratesNotifier.setCategory(current == RateCategory.favorites
                    ? RateCategory.all
                    : RateCategory.favorites);
              },
              icon: const Icon(Icons.star_outline_rounded),
            ),
            IconButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PriceAlarmsPage(),
                  ),
                );
              },
              icon: const Icon(
                Icons.notifications_active_rounded,
              ),
            ),
            IconButton(
              onPressed: () {
                _openSearchSheet(context, ref);
              },
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RatesCategoryBar(state: state),
              const SizedBox(height: 8),
              if (state.category == RateCategory.metals)
                _MetalFilters(state: state),
              if (state.category == RateCategory.metals)
                const SizedBox(height: 8),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.read(lastRatesRefreshAtProvider.notifier).state = DateTime.now();
                    try {
                      await Future.wait([
                        ref.read(usdTryRateProvider.notifier).refresh(),
                        ref.read(eurTryRateProvider.notifier).refresh(),
                        ref.read(bigparaByKeyProvider.notifier).refresh(),
                        ref.read(goldPriceProvider.notifier).refresh(),
                      ]).timeout(const Duration(seconds: 25));
                      await ref.read(ratesPricesCacheProvider.notifier).refresh();
                    } catch (_) {
                      // Timeout veya ağ hatası; yenileme biter, kullanıcı tekrar deneyebilir.
                    }
                  },
                  child: filteredItems.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 48),
                              child: EmptyStateView(
                                icon: Icons.search_off_rounded,
                                title: 'Kayıt bulunamadı',
                                description: 'Seçili filtreye uygun kurlar yok. Filtreleri değiştir veya favorilere kayıt ekle.',
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isFavorite =
                                state.favorites.contains(item.id);
                            return _RateCard(
                              item: item,
                              isFavorite: isFavorite,
                              onToggleFavorite: () => ref
                                  .read(ratesProvider.notifier)
                                  .toggleFavorite(item.id),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Expanded(child: Text(
                    'Veriler kaynaklarına göre güncellenir',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.65),
                        ),
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatLastUpdate(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  final s = dt.second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

void _openSearchSheet(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  final current = ref.read(ratesSearchQueryProvider) ?? '';
  final controller = TextEditingController(text: current);

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Varlık ara',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Varlık adı veya kodu',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _applySearch(ref, controller.text);
                Navigator.of(ctx).pop();
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _applySearch(ref, controller.text);
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Uygula'),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    ref.read(ratesSearchQueryProvider.notifier).state = null;
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Temizle'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void _applySearch(WidgetRef ref, String text) {
  final q = text.trim();
  ref.read(ratesSearchQueryProvider.notifier).state =
      q.isEmpty ? null : q;
}

class _RatesCategoryBar extends ConsumerWidget {
  const _RatesCategoryBar({required this.state});

  final RatesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ratesProvider.notifier);

    Widget chip(RateCategory category, String label) {
      final selected = state.category == category;
      final theme = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      return Padding(padding: const EdgeInsets.only(right: 8), child: TextButton(
        onPressed: () => notifier.setCategory(category),
        style: TextButton.styleFrom(
          backgroundColor: selected ? (dark ? const Color(0xFFE1C488) : const Color(0xFF252933)) : theme.colorScheme.surface,
          foregroundColor: selected ? (dark ? const Color(0xFF1D1D1D) : Colors.white) : theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
          shape: const StadiumBorder(), textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ), child: Text(label),
      ));
    }
    return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      chip(RateCategory.all, 'Tümü'),
      chip(RateCategory.currency, 'Döviz'),
      chip(RateCategory.metals, 'Altın & maden'),
      chip(RateCategory.coins, 'Kripto'),
      chip(RateCategory.favorites, 'Favoriler'),
    ]));
  }
}

class _MetalFilters extends ConsumerWidget {
  const _MetalFilters({required this.state});

  final RatesState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ratesProvider.notifier);

    Widget assetChip(AssetType? type, String label) {
      final selected = state.selectedAssetType == type;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          notifier.setSelectedAssetType(selected ? null : type);
        },
      );
    }

    Widget purityChip(GoldPurity? purity, String label) {
      final selected = state.selectedGoldPurity == purity;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          notifier.setSelectedGoldPurity(selected ? null : purity);
        },
      );
    }

    Widget metalGroupChip(String? group, String label) {
      final selected = state.selectedMetalGroup == group;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          notifier.setSelectedMetalGroup(selected ? null : group);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Maden türü'),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              metalGroupChip(null, 'Tümü'),
              const SizedBox(width: 8),
              metalGroupChip('gold', 'Altın'),
              const SizedBox(width: 8),
              metalGroupChip('silver', 'Gümüş'),
              const SizedBox(width: 8),
              metalGroupChip('platinum', 'Platin'),
              const SizedBox(width: 8),
              metalGroupChip('other', 'Diğer madenler'),
            ],
          ),
        ),
        if (state.selectedMetalGroup == 'gold') ...[
          const SizedBox(height: 8),
          const Text('Altın türü'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                assetChip(null, 'Tümü'),
                const SizedBox(width: 8),
                assetChip(AssetType.gramAltin, 'Gram Altın'),
                const SizedBox(width: 8),
                assetChip(AssetType.onsAltin, 'Ons Altın'),
              ],
            ),
          ),
          if (state.selectedAssetType != null) ...[
            const SizedBox(height: 8),
            const Text('Ayar'),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  purityChip(null, 'Tümü'),
                  const SizedBox(width: 8),
                  purityChip(GoldPurity.carat24, '24 Ayar'),
                  if (state.selectedAssetType != AssetType.onsAltin) ...[
                    const SizedBox(width: 8),
                    purityChip(GoldPurity.carat22, '22 Ayar'),
                    const SizedBox(width: 8),
                    purityChip(GoldPurity.carat18, '18 Ayar'),
                    const SizedBox(width: 8),
                    purityChip(GoldPurity.carat14, '14 Ayar'),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _RateCard extends ConsumerStatefulWidget {
  const _RateCard({
    required this.item,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final RateItem item;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  ConsumerState<_RateCard> createState() => _RateCardState();
}

class _RateCardState extends ConsumerState<_RateCard> {
  bool _expanded = false;
  bool _showVendors = false;

  /// Tüm varlıklar: renkli daire + sembol (coin/maden). Ağ isteği yok, donma önlenir.
  Widget _buildRateItemAvatar(
      BuildContext context, RateItem item, Color assetColor) {
    return _metalAvatar(context, item, assetColor, 22.0);
  }

  Widget _metalAvatar(
      BuildContext context, RateItem item, Color assetColor, double radius) {
    final theme = Theme.of(context);
    final color = item.type == RateType.metal ? theme.colorScheme.primary : assetColor;
    return Container(
      width: radius * 2, height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(15)),
      child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(5), child: Text(item.code,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: item.type == RateType.metal ? color : theme.colorScheme.onSurface)))),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.item.type) {
      case RateType.metal:
      case RateType.coin:
        return _buildSimpleCard(context);
      case RateType.bank:
        return _buildBankCard(context);
    }
  }

  Widget _buildSimpleCard(BuildContext context) {
    final item = widget.item;
    final price = item.lastPrice;
    final change = item.changePercent;
    final isUp = (change ?? 0) >= 0;
    final changeColor =
        change == null ? Colors.grey : (isUp ? Colors.green : Colors.red);

    final allRatesItems = ref.watch(ratesListProvider);
    final vendors = allRatesItems
        .where((v) =>
            v.type == RateType.bank &&
            v.assetType == item.assetType &&
            v.goldPurity == item.goldPurity &&
            v.sellPrice != null)
        .toList()
      ..sort((a, b) => a.sellPrice!.compareTo(b.sellPrice!));

    final hasVendors = item.type == RateType.metal &&
        item.assetType != null &&
        item.goldPurity != null &&
        vendors.isNotEmpty;

    final assetColor = _assetColor(item.id, item.type);
    final theme = Theme.of(context);
    final buy = item.buyPrice;
    final sell = item.sellPrice;
    final low = item.dailyLow;
    final high = item.dailyHigh;
    final closing = item.closingPrice;
    final lastUpdated = item.lastUpdated;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Row(
                  children: [
                    _buildRateItemAvatar(context, item, assetColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.code,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                              fontWeight: item.type == RateType.metal
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          if (item.subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.subtitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (price != null)
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('₺${formatMoney(price)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            if (change != null)
                              Text('${isUp ? '+' : ''}${change.toStringAsFixed(2)}%',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: changeColor)),
                          ],
                        ),
                      ),
                    IconButton(
                      onPressed: widget.onToggleFavorite,
                      tooltip: widget.isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40), padding: EdgeInsets.zero),
                      icon: Icon(widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 22, color: widget.isFavorite ? Colors.amber : theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _detailPriceCell(context, 'ALIŞ', buy, null)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailPriceCell(context, 'SATIŞ', sell, null)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _detailPriceCell(context, 'DÜŞÜK', low, Colors.red)),
                  const SizedBox(width: 8),
                  Expanded(child: _detailPriceCell(context, 'YÜKSEK', high, Colors.green)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAlarmSheet(context, item, price),
                      icon: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                      ),
                      label: const Text('Alarm Oluştur'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onToggleFavorite,
                      icon: Icon(
                        widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                        size: 18,
                        color: widget.isFavorite ? Colors.amber : null,
                      ),
                      label: Text(widget.isFavorite ? 'Favoriden Çıkar' : 'Favorilere Ekle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.nightlight_round, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text(
                        'Kapanış: ${closing != null ? '₺${formatMoney(closing)}' : '-'}',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Text(
                        lastUpdated != null ? _formatTime(lastUpdated) : '—',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.8)),
                      ),
                    ],
                  ),
                ],
              ),
              if (hasVendors) ...[
                const SizedBox(height: 14),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _showVendors = !_showVendors),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Diğer fiyatlar (${vendors.length} satıcı)',
                                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Icon(
                                _showVendors ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                size: 22,
                                color: theme.colorScheme.primary,
                              ),
                            ],
                          ),
                          if (_showVendors) ...[
                            const SizedBox(height: 6),
                            Text(
                              'En düşük alış fiyatından yükseğe doğru sıralanmıştır.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _VendorListInline(
                              assetName: item.name,
                              assetType: item.assetType!,
                              goldPurity: item.goldPurity!,
                              vendors: vendors,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Widget _detailPriceCell(BuildContext context, String label, double? value, Color? valueColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value != null ? '₺${formatMoney(value)}' : '-',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  void _openAlarmSheet(BuildContext context, RateItem item, double? currentPrice) {
    final theme = Theme.of(context);
    final controller = TextEditingController(
      text: currentPrice != null ? formatMoney(currentPrice) : '',
    );
    AlarmDirection direction = AlarmDirection.above;

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
                        'Fiyat alarmı oluştur',
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
                    item.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                  if (currentPrice != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Anlık fiyat: ₺${formatMoney(currentPrice)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                        final text = controller.text.replaceAll(',', '.').trim();
                        final value = double.tryParse(text);
                        if (value == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Geçerli bir hedef fiyat gir.'),
                            ),
                          );
                          return;
                        }
                        ref.read(priceAlarmsProvider.notifier).addAlarm(
                              assetId: item.id,
                              assetName: item.name,
                              direction: direction,
                              targetPrice: value,
                            );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${item.name} için ₺${formatMoney(value)} seviyesinde alarm kaydedildi.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: const Text('Alarmı Kaydet'),
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

  Widget _buildBankCard(BuildContext context) {
    final buy = widget.item.buyPrice;
    final sell = widget.item.sellPrice;
    final spread = widget.item.spread;
    final spreadPct = widget.item.spreadPercent;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(
                Icons.account_balance_rounded,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (spreadPct != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: Colors.green.withOpacity(0.12),
                          ),
                          child: Text(
                            'Makas %${spreadPct.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _bankValueColumn('Alış', buy),
                      _bankValueColumn('Satış', sell),
                      _bankValueColumn('Makas', spread),
                    ],
                  ),
                  if (widget.item.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.item.subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: widget.onToggleFavorite,
              icon: Icon(
                widget.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: widget.isFavorite ? Colors.amber : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bankValueColumn(String label, double? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value != null ? '₺${formatMoney(value)}' : '-',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class VendorComparisonPage extends ConsumerWidget {
  const VendorComparisonPage({
    super.key,
    required this.assetName,
    required this.assetType,
    required this.goldPurity,
  });

  final String assetName;
  final AssetType assetType;
  final GoldPurity goldPurity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allItems = ref.watch(ratesListProvider);
    final vendors = allItems
        .where((item) =>
            item.type == RateType.bank &&
            item.assetType == assetType &&
            item.goldPurity == goldPurity &&
            item.sellPrice != null)
        .toList()
      ..sort((a, b) => a.sellPrice!.compareTo(b.sellPrice!));

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(assetName),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: vendors.isEmpty
              ? Center(
                  child: Text(
                    'Bu varlık için kayıtlı banka fiyatı bulunmuyor.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  itemCount: vendors.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final v = vendors[index];
                    final spread = v.spread;
                    final spreadPct = v.spreadPercent;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.12),
                              foregroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.account_balance_rounded,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        v.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (spreadPct != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            color: Colors.green
                                                .withOpacity(0.12),
                                          ),
                                          child: Text(
                                            'Makas %${spreadPct.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _VendorComparisonValueColumn(
                                        label: 'Alış',
                                        value: v.buyPrice,
                                      ),
                                      _VendorComparisonValueColumn(
                                        label: 'Satış',
                                        value: v.sellPrice,
                                      ),
                                      _VendorComparisonValueColumn(
                                        label: 'Makas',
                                        value: spread,
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

class _VendorComparisonValueColumn extends StatelessWidget {
  const _VendorComparisonValueColumn({
    required this.label,
    required this.value,
  });

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value != null ? '₺${value!.toStringAsFixed(2)}' : '-',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _VendorListInline extends StatelessWidget {
  const _VendorListInline({
    required this.assetName,
    required this.assetType,
    required this.goldPurity,
    required this.vendors,
  });

  final String assetName;
  final AssetType assetType;
  final GoldPurity goldPurity;
  final List<RateItem> vendors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...vendors.asMap().entries.map((entry) {
          final index = entry.key;
          final v = entry.value;
          final isFirst = index == 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    foregroundColor: theme.colorScheme.primary,
                    radius: 18,
                    child: const Icon(
                      Icons.storefront_rounded,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (v.buyPrice != null || v.sellPrice != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (v.buyPrice != null)
                                Text(
                                  'Alış: ₺${formatMoney(v.buyPrice!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                              if (v.buyPrice != null && v.sellPrice != null)
                                const SizedBox(width: 8),
                              if (v.sellPrice != null)
                                Text(
                                  'Satış: ₺${formatMoney(v.sellPrice!)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    v.sellPrice != null
                        ? '₺${formatMoney(v.sellPrice!)}'
                        : (v.buyPrice != null
                            ? '₺${formatMoney(v.buyPrice!)}'
                            : '-'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isFirst
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        if (vendors.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VendorComparisonPage(
                        assetName: assetName,
                        assetType: assetType,
                        goldPurity: goldPurity,
                      ),
                    ),
                  );
                },
                child: const Text('Tümünü gör'),
              ),
            ),
          ),
      ],
    );
  }
}

class _LiveStatusBadge extends StatefulWidget {
  const _LiveStatusBadge();

  @override
  State<_LiveStatusBadge> createState() => _LiveStatusBadgeState();
}

class _LiveStatusBadgeState extends State<_LiveStatusBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeInOut,
        ),
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.04).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: Colors.green),
              SizedBox(width: 6),
              Text(
                'Piyasa',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

