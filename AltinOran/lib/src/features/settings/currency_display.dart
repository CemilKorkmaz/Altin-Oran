import '../../core/formatting.dart';
import 'application/settings_providers.dart';

/// TL cinsinden tutarı, seçili görüntü para birimine göre formatlar.
/// Kur yoksa TL gösterilir.
String formatDisplayCurrency(
  double amountTl,
  DisplayCurrency currency,
  double? usdTryRate,
  double? eurTryRate,
) {
  switch (currency) {
    case DisplayCurrency.tl:
      return '₺${formatMoney(amountTl)}';
    case DisplayCurrency.usd:
      if (usdTryRate != null && usdTryRate > 0) {
        return '\$${formatMoney(amountTl / usdTryRate)}';
      }
      return '₺${formatMoney(amountTl)}';
    case DisplayCurrency.eur:
      if (eurTryRate != null && eurTryRate > 0) {
        return '€${formatMoney(amountTl / eurTryRate)}';
      }
      return '₺${formatMoney(amountTl)}';
  }
}
