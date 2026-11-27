import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gramhane is an independent public market-data provider, not an exchange.
class MarketQuote {
  const MarketQuote({this.buy, this.sell, this.changePercent});
  final double? buy;
  final double? sell;
  final double? changePercent;
  double? get price => sell ?? buy;
}

class TurkishMarketSnapshot {
  const TurkishMarketSnapshot({required this.updatedAt, required this.quotes});
  final DateTime updatedAt;
  final Map<String, MarketQuote> quotes;
  bool get isDelayed => DateTime.now().toUtc().difference(updatedAt.toUtc()) > const Duration(minutes: 20);
}

class TurkishMarketClient {
  TurkishMarketClient(this._client);
  final http.Client _client;
  static final Uri endpoint = Uri.https('api.gramhane.com', '/v1/prices.json');

  Future<TurkishMarketSnapshot?> fetch() async {
    try {
      final response = await _client.get(endpoint, headers: {
        'Accept': 'application/json', 'User-Agent': 'AltinOran/0.4',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      return parse(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// API timestamps are Istanbul time (UTC+3), independently of phone timezone.
  static TurkishMarketSnapshot? parse(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map<String, dynamic>) return null;
      final meta = data['meta'];
      if (meta is! Map || meta['status'] != 'success' || meta['tarih'] is! String) return null;
      final text = meta['tarih'] as String;
      if (!RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$').hasMatch(text)) return null;
      final updatedAt = DateTime.tryParse('${text.replaceFirst(' ', 'T')}+03:00');
      if (updatedAt == null || updatedAt.isAfter(DateTime.now().toUtc().add(const Duration(minutes: 5)))) return null;
      final rates = data['kurlar'];
      final jewelry = data['ziynet_ve_diger'];
      if (rates is! Map || jewelry is! Map) return null;
      final mapping = <String, dynamic>{
        'gold_gram': rates['ALTIN'],
        'silver_gram': rates['GUMUS'],
        'gold_ceyrek': jewelry['Çeyrek (Yeni)'],
        'gold_yarim': jewelry['Yarım (Yeni)'],
        'gold_tam': jewelry['Ziynet Lira (Yeni)'],
        'gold_cumhuriyet': jewelry['Cumhuriyet'],
        'gold_bilezik22': jewelry['22 Ayar Bilezik'],
        'gold_gram_18': jewelry['18 Ayar'],
        'gold_gram_14': jewelry['14 Ayar'],
      };
      double? number(dynamic value, {bool positive = true}) {
        final v = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
        if (v == null || !v.isFinite || (positive && v <= 0)) return null;
        return v;
      }
      final quotes = <String, MarketQuote>{};
      for (final entry in mapping.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final quote = MarketQuote(buy: number(value['alis']), sell: number(value['satis']), changePercent: number(value['yuzde'], positive: false));
        if (quote.price != null) quotes[entry.key] = quote;
      }
      if (!quotes.containsKey('gold_gram')) return null;
      return TurkishMarketSnapshot(updatedAt: updatedAt, quotes: Map.unmodifiable(quotes));
    } catch (_) {
      return null;
    }
  }
}
