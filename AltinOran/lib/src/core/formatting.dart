/// Parasal değer formatı:
/// - Tam sayı ise ondalık göstermez (1002 -> "1002")
/// - Kuruş varsa 2 ondalık gösterir (1002.48 -> "1002.48")
String formatMoney(num value) {
  if (value.isNaN || value.isInfinite) {
    return '0';
  }
  final doubleVal = value.toDouble();

  // Küçük kayan nokta hatalarını yumuşatmak için yuvarla.
  final rounded = doubleVal.roundToDouble();
  if ((doubleVal - rounded).abs() < 0.005) {
    return rounded.toStringAsFixed(0);
  }
  return doubleVal.toStringAsFixed(2);
}

/// İşaretli TL formatı: "₺123" veya "-₺123.45"
String formatSignedTl(double v) {
  final absStr = formatMoney(v.abs());
  return v >= 0 ? '₺$absStr' : '-₺$absStr';
}

