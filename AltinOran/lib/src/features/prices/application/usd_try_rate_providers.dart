import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gold_price_providers.dart';

class UsdTryRateState {
  const UsdTryRateState({
    required this.isLoading,
    this.rate,
    this.errorMessage,
  });

  final bool isLoading;
  final double? rate;
  final String? errorMessage;

  UsdTryRateState copyWith({
    bool? isLoading,
    double? rate,
    String? errorMessage,
  }) {
    return UsdTryRateState(
      isLoading: isLoading ?? this.isLoading,
      rate: rate ?? this.rate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static UsdTryRateState initial() =>
      const UsdTryRateState(isLoading: false, rate: null, errorMessage: null);
}

class UsdTryRateNotifier extends StateNotifier<UsdTryRateState> {
  UsdTryRateNotifier(this._ref) : super(UsdTryRateState.initial()) {
    // Uygulama açıldığında otomatik olarak son kuru çek.
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rate = await _fetchFromApi();
      state = UsdTryRateState(
        isLoading: false,
        rate: rate,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Döviz kuru alınamadı',
      );
    }
  }

  Future<double> _fetchFromApi() async {
    // Google sonuçlarını doğrudan okumak yerine, ücretsiz bir kur API'si kullanıyoruz.
    // Frankfurter API: https://www.frankfurter.app/docs/
    final client = _ref.read(httpClientProvider);
    final uri = Uri.https(
      'api.frankfurter.app',
      '/latest',
      {
        'from': 'USD',
        'to': 'TRY',
      },
    );

    final response = await client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = body['rates'] as Map<String, dynamic>?;
    if (rates == null || !rates.containsKey('TRY')) {
      throw Exception('TRY rate not found');
    }

    return (rates['TRY'] as num).toDouble();
  }
}

final usdTryRateProvider =
    StateNotifierProvider<UsdTryRateNotifier, UsdTryRateState>((ref) {
  return UsdTryRateNotifier(ref);
});

