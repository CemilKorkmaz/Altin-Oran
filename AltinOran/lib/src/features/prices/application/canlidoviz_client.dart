import 'dart:convert';

import 'package:http/http.dart' as http;

/// Canlidoviz.com API — ücretsiz, Türkiye odaklı.
/// Kaynak: https://github.com/trbasoglu/doviz-borsa-kripto-api
/// Altın: type=1, Döviz: type=0, Kripto: type=2
class CanlidovizClient {
  CanlidovizClient(this._client);

  final http.Client _client;

  static const _timeout = Duration(seconds: 10);
  static const _host = 'api.canlidoviz.com';

  /// Gram altın TL fiyatı (ortalama veya alış). Başarısızsa null.
  /// type=1 → altın listesi (Gram Altın, Çeyrek vb.)
  Future<double?> fetchGramAltinTry() async {
    final uri = Uri.https(_host, '/web/items', {'marketId': '1', 'type': '1'});
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return _parseGramAltinPrice(res.body);
    } catch (_) {
      return null;
    }
  }

  /// JSON yanıtından "Gram Altın" (24 ayar) TL fiyatını çıkarır.
  double? _parseGramAltinPrice(String body) {
    try {
      final decoded = jsonDecode(body);
      // Liste veya { "items": [...] } veya { "data": [...] }
      List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        final items = decoded['items'];
        final data = decoded['data'];
        list = items is List ? items : (data is List ? data : <dynamic>[]);
      } else {
        return null;
      }

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final name = (item['name'] ?? item['title'] ?? item['code'] ?? '').toString().toLowerCase();
        final code = (item['code'] ?? '').toString().toUpperCase();
        // Gram altın 24 ayar: "gram altın", "gram altin", "GAU" vb.
        final isGramAltin = name.contains('gram') && (name.contains('altın') || name.contains('altin')) ||
            code == 'GAU' ||
            (item['symbol'] ?? '').toString().toLowerCase().contains('gram');
        if (!isGramAltin) continue;

        // Alış, satış veya tek fiyat
        final buying = _numFrom(item['buying'] ?? item['buy'] ?? item['alis']);
        final selling = _numFrom(item['selling'] ?? item['sell'] ?? item['satis']);
        final last = _numFrom(item['lastPrice'] ?? item['price'] ?? item['rate'] ?? item['close']);
        final price = buying ?? selling ?? last;
        if (price != null && price > 0) return price;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  double? _numFrom(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.').trim());
    return null;
  }
}
