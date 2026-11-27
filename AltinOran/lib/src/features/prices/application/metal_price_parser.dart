/// MetalPriceAPI returns `XAG` as ounces per unit of the base currency,
/// and may also return `USDXAG` as the inverse, currency per ounce.
/// Unknown or invalid rates are unavailable, never guessed.
double? metalPricePerOunce(Map<String, dynamic> rates, String metal, String base) {
  double? number(dynamic value) {
    final parsed = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
  }

  final direct = number(rates['$base$metal']);
  if (direct != null) return direct;
  final inverse = number(rates[metal]);
  return inverse == null ? null : 1 / inverse;
}
