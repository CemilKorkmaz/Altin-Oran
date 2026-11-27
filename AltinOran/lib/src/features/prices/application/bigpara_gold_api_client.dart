import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// gold-api backend'inden (Bigpara) tüm altın/gümüş/platin fiyatlarını çeker.
/// GET /api/prices/gold → byKey (gram_altin, ceyrek, yarim, silver_gram, ons, vb.)
class BigparaGoldApiClient {
  BigparaGoldApiClient(this._client);

  final http.Client _client;

  /// Tüm byKey verisini döndürür (gram_altin, ceyrek, yarim, tam, cumhuriyet, bilezik_22, ons, silver_gram, silver_ons, platinum_gram, platinum_ons, gram_22, gram_18, gram_14).
  Future<Map<String, Map<String, dynamic>>?> fetchAllByKey() async {
    final baseUrl = bigparaGoldApiBaseUrl;
    if (baseUrl.isEmpty) return null;
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final fullUri = Uri.parse('${base}api/prices/gold');
    try {
      final response = await _client.get(fullUri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) return null;
      final byKey = body['byKey'] as Map<String, dynamic>?;
      if (byKey == null) return null;
      final result = <String, Map<String, dynamic>>{};
      for (final e in byKey.entries) {
        if (e.value is Map) result[e.key] = Map<String, dynamic>.from(e.value as Map);
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  /// Gram altın TL/gr fiyatı (geriye uyumluluk).
  Future<double?> fetchGramAltinTry() async {
    final baseUrl = bigparaGoldApiBaseUrl;
    if (baseUrl.isEmpty) return null;

    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final fullUri = Uri.parse('${base}api/prices/gold');

    try {
      final response = await _client.get(fullUri).timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) return null;

      // ok: false olsa bile items dolu olabilir (backend parse kısmen başarılı)
      // Önce byKey.gram_altin
      final byKey = body['byKey'] as Map<String, dynamic>?;
      if (byKey != null) {
        final gram = byKey['gram_altin'] as Map<String, dynamic>?;
        if (gram != null) {
          final alis = _num(gram['alis']);
          final satis = _num(gram['satis']);
          if (satis != null && satis > 0) return satis;
          if (alis != null && alis > 0) return alis;
          if (alis != null && satis != null) return (alis + satis) / 2;
        }
      }

      // byKey boşsa items içinden "ALTIN (TL/GR)" veya "Gram" ara
      final items = body['items'] as List<dynamic>?;
      if (items != null) {
        for (final e in items) {
          if (e is! Map<String, dynamic>) continue;
          final name = (e['name'] as String? ?? '').toLowerCase();
          if (!name.contains('tl/gr') && !name.contains('gram altın')) continue;
          if (name.contains('22') || name.contains('18') || name.contains('14')) continue;
          final alis = _num(e['alis']);
          final satis = _num(e['satis']);
          if (satis != null && satis > 0) return satis;
          if (alis != null && alis > 0) return alis;
          if (alis != null && satis != null) return (alis + satis) / 2;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
}
