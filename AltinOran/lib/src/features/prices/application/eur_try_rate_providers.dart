import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'gold_price_providers.dart';

class EurTryRateState {
  const EurTryRateState({
    required this.isLoading,
    this.rate,
    this.errorMessage,
  });

  final bool isLoading;
  final double? rate;
  final String? errorMessage;

  EurTryRateState copyWith({
    bool? isLoading,
    double? rate,
    String? errorMessage,
  }) {
    return EurTryRateState(
      isLoading: isLoading ?? this.isLoading,
      rate: rate ?? this.rate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static EurTryRateState initial() =>
      const EurTryRateState(isLoading: false, rate: null, errorMessage: null);
}

class EurTryRateNotifier extends StateNotifier<EurTryRateState> {
  EurTryRateNotifier(this._ref) : super(EurTryRateState.initial()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final rate = await _fetchFromApi();
      state = EurTryRateState(
        isLoading: false,
        rate: rate,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'EUR kuru alınamadı',
      );
    }
  }

  Future<double> _fetchFromApi() async {
    final client = _ref.read(httpClientProvider);
    final uri = Uri.https(
      'api.frankfurter.app',
      '/latest',
      {'from': 'EUR', 'to': 'TRY'},
    );
    final response = await client.get(uri);
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

final eurTryRateProvider =
    StateNotifierProvider<EurTryRateNotifier, EurTryRateState>((ref) {
  return EurTryRateNotifier(ref);
});
