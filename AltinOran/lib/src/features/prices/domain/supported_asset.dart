import 'package:flutter/foundation.dart';

/// Varlık kategorisi: canlı fiyat ve birikimde gruplama için.
enum AssetCategory {
  gold,
  silver,
  platinum,
  metal,
  crypto,
  /// Döviz (USD, EUR vb.)
  currency,
}

/// Uygulamada kullanılan tüm varlıkların kataloğu.
/// [symbol] kripto için Binance sembolü (örn. BTCUSDT); madencilere gram/ons için boş veya kaynak bilgisi.
@immutable
class SupportedAsset {
  const SupportedAsset({
    required this.id,
    required this.name,
    required this.category,
    this.symbol,
    this.unitLabel = 'gr',
  });

  final String id;
  final String name;
  final AssetCategory category;

  /// Binance vb. API için sembol (örn. BTCUSDT). Kripto dışında null olabilir.
  final String? symbol;

  /// Birim etiketi: gr, adet, BTC, USD vb.
  final String unitLabel;

  /// Kripto mu (Binance'den fiyat alınacak).
  bool get isCrypto => category == AssetCategory.crypto;
}

// ——— Ön tanımlı katalog ———

const List<SupportedAsset> _goldAssets = [
  SupportedAsset(id: 'gold_gram', name: 'Gram Altın', category: AssetCategory.gold, unitLabel: 'gr'),
  SupportedAsset(id: 'gold_ceyrek', name: 'Çeyrek Altın', category: AssetCategory.gold, unitLabel: 'adet'),
  SupportedAsset(id: 'gold_yarim', name: 'Yarım Altın', category: AssetCategory.gold, unitLabel: 'adet'),
  SupportedAsset(id: 'gold_tam', name: 'Tam Altın', category: AssetCategory.gold, unitLabel: 'adet'),
  SupportedAsset(id: 'gold_cumhuriyet', name: 'Cumhuriyet Altını', category: AssetCategory.gold, unitLabel: 'adet'),
  SupportedAsset(id: 'gold_bilezik22', name: '22 Ayar Bilezik', category: AssetCategory.gold, unitLabel: 'gr'),
  SupportedAsset(id: 'gold_ons', name: 'Ons Altın', category: AssetCategory.gold, unitLabel: 'gr'),
];

const List<SupportedAsset> _silverAssets = [
  SupportedAsset(id: 'silver_gram', name: 'Gram Gümüş', category: AssetCategory.silver, unitLabel: 'gr'),
  SupportedAsset(id: 'silver_ons', name: 'Ons Gümüş', category: AssetCategory.silver, unitLabel: 'gr'),
];

const List<SupportedAsset> _platinumAssets = [
  SupportedAsset(id: 'platinum_gram', name: 'Gram Platin', category: AssetCategory.platinum, unitLabel: 'gr'),
  SupportedAsset(id: 'platinum_ons', name: 'Ons Platin', category: AssetCategory.platinum, unitLabel: 'gr'),
];

const List<SupportedAsset> _metalAssets = [
  SupportedAsset(id: 'metal_palladium_gram', name: 'Gram Paladyum', category: AssetCategory.metal, unitLabel: 'gr'),
  SupportedAsset(id: 'metal_rhodium', name: 'Rodyum', category: AssetCategory.metal, unitLabel: 'gr'),
];

/// Dövizler (şimdilik USD / EUR). Birim: 1 birim döviz.
const List<SupportedAsset> _currencyAssets = [
  SupportedAsset(
    id: 'fx_usd_try',
    name: 'Dolar (USD)',
    category: AssetCategory.currency,
    unitLabel: 'USD',
  ),
  SupportedAsset(
    id: 'fx_eur_try',
    name: 'Euro (EUR)',
    category: AssetCategory.currency,
    unitLabel: 'EUR',
  ),
];

/// Popüler 20 kripto para (Binance sembolü ile; fiyat sonra Binance API'den alınacak).
const List<SupportedAsset> _top20Coins = [
  SupportedAsset(id: 'crypto_btc', name: 'Bitcoin', category: AssetCategory.crypto, symbol: 'BTCUSDT', unitLabel: 'BTC'),
  SupportedAsset(id: 'crypto_eth', name: 'Ethereum', category: AssetCategory.crypto, symbol: 'ETHUSDT', unitLabel: 'ETH'),
  SupportedAsset(id: 'crypto_bnb', name: 'BNB', category: AssetCategory.crypto, symbol: 'BNBUSDT', unitLabel: 'BNB'),
  SupportedAsset(id: 'crypto_xrp', name: 'XRP', category: AssetCategory.crypto, symbol: 'XRPUSDT', unitLabel: 'XRP'),
  SupportedAsset(id: 'crypto_ada', name: 'Cardano', category: AssetCategory.crypto, symbol: 'ADAUSDT', unitLabel: 'ADA'),
  SupportedAsset(id: 'crypto_sol', name: 'Solana', category: AssetCategory.crypto, symbol: 'SOLUSDT', unitLabel: 'SOL'),
  SupportedAsset(id: 'crypto_doge', name: 'Dogecoin', category: AssetCategory.crypto, symbol: 'DOGEUSDT', unitLabel: 'DOGE'),
  SupportedAsset(id: 'crypto_dot', name: 'Polkadot', category: AssetCategory.crypto, symbol: 'DOTUSDT', unitLabel: 'DOT'),
  SupportedAsset(id: 'crypto_avax', name: 'Avalanche', category: AssetCategory.crypto, symbol: 'AVAXUSDT', unitLabel: 'AVAX'),
  SupportedAsset(id: 'crypto_matic', name: 'Polygon', category: AssetCategory.crypto, symbol: 'MATICUSDT', unitLabel: 'MATIC'),
  SupportedAsset(id: 'crypto_ltc', name: 'Litecoin', category: AssetCategory.crypto, symbol: 'LTCUSDT', unitLabel: 'LTC'),
  SupportedAsset(id: 'crypto_link', name: 'Chainlink', category: AssetCategory.crypto, symbol: 'LINKUSDT', unitLabel: 'LINK'),
  SupportedAsset(id: 'crypto_uni', name: 'Uniswap', category: AssetCategory.crypto, symbol: 'UNIUSDT', unitLabel: 'UNI'),
  SupportedAsset(id: 'crypto_atom', name: 'Cosmos', category: AssetCategory.crypto, symbol: 'ATOMUSDT', unitLabel: 'ATOM'),
  SupportedAsset(id: 'crypto_xlm', name: 'Stellar', category: AssetCategory.crypto, symbol: 'XLMUSDT', unitLabel: 'XLM'),
  SupportedAsset(id: 'crypto_bch', name: 'Bitcoin Cash', category: AssetCategory.crypto, symbol: 'BCHUSDT', unitLabel: 'BCH'),
  SupportedAsset(id: 'crypto_etc', name: 'Ethereum Classic', category: AssetCategory.crypto, symbol: 'ETCUSDT', unitLabel: 'ETC'),
  SupportedAsset(id: 'crypto_xmr', name: 'Monero', category: AssetCategory.crypto, symbol: 'XMRUSDT', unitLabel: 'XMR'),
  SupportedAsset(id: 'crypto_trx', name: 'TRON', category: AssetCategory.crypto, symbol: 'TRXUSDT', unitLabel: 'TRX'),
  SupportedAsset(id: 'crypto_fil', name: 'Filecoin', category: AssetCategory.crypto, symbol: 'FILUSDT', unitLabel: 'FIL'),
];

/// Tüm ön tanımlı varlıklar (kullanıcı eklemeden önce).
/// Sabit referans: provider her okunduğunda yeni liste üretilmesin, donma olmasın.
final List<SupportedAsset> predefinedSupportedAssets = [
  ..._goldAssets,
  ..._silverAssets,
  ..._platinumAssets,
  ..._metalAssets,
  ..._currencyAssets,
  ..._top20Coins,
];

String categoryLabel(AssetCategory c) {
  switch (c) {
    case AssetCategory.gold:
      return 'Altın türleri';
    case AssetCategory.silver:
      return 'Gümüş türleri';
    case AssetCategory.platinum:
      return 'Platin türleri';
    case AssetCategory.metal:
      return 'Diğer madener';
    case AssetCategory.crypto:
      return 'Popüler coinler';
    case AssetCategory.currency:
      return 'Dövizler';
  }
}
