import 'dart:convert';

import 'package:http/http.dart' as http;

/// Kapalıçarşı / Türkiye piyasası gram altın fiyatı (TL).
/// 3. taraf projeler (örn. kapali-carsi-altin-api.vercel.app) JSON döndürüyorsa kullanılır.
class KapalicarsiClient {
  KapalicarsiClient(this._client);

  final http.Client _client;

  static const _timeout = Duration(seconds: 8);
  static const _host = 'kapali-carsi-altin-api.vercel.app';

  /// Gram altın TL fiyatı döner; başarısızsa null.
  /// Denenecek URL'ler: /api, /api/prices, /api/gold (projeye göre değişir).
  Future<double?> fetchGramAltinTry() async {
    final uris = [
      Uri.https(_host, '/api/prices'),
      Uri.https(_host, '/api/gold'),
      Uri.https(_host, '/api'),
    ];
    for (final uri in uris) {
      try {
        final res = await _client.get(uri).timeout(_timeout);
        if (res.statusCode != 200) continue;
        final v = _parseGramPrice(res.body);
        if (v != null && v > 0) return v;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  /// JSON veya benzeri yapıdan gram altın TL değerini çıkarır.
  /// Farklı projeler farklı format kullanabilir; yaygın anahtarlar denenir.
  double? _parseGramPrice(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      // Örnek: { "gram_altin": 2500.5 } veya { "prices": { "gram": 2500 } }
      final map = decoded;
      for (final key in ['gram_altin', 'gramAltin', 'gram', 'gram_altin_alis', 'alis']) {
        final v = map[key];
        if (v is num) return v.toDouble();
        if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      }
      final prices = map['prices'] as Map<String, dynamic>?;
      if (prices != null) {
        final v = prices['gram'] ?? prices['gram_altin'];
        if (v is num) return v.toDouble();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
