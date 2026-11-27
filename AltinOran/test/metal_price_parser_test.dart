import 'package:flutter_test/flutter_test.dart';
import 'package:birikim_portfoy/src/features/prices/application/metal_price_parser.dart';

void main() {
  test('inverts metal units per USD to dollars per ounce', () {
    expect(metalPricePerOunce({'XAG': 0.02}, 'XAG', 'USD'), 50);
    expect(metalPricePerOunce({'XAU': 0.0005}, 'XAU', 'USD'), 2000);
  });
  test('uses an explicit metal-to-base quote without inverting', () {
    expect(metalPricePerOunce({'XAG': 0.02, 'USDXAG': 50}, 'XAG', 'USD'), 50);
    expect(metalPricePerOunce({'TRYXAU': 100000}, 'XAU', 'TRY'), 100000);
  });
  test('rejects invalid and missing rates', () {
    for (final value in [0, -1, 'invalid', double.nan, double.infinity]) {
      expect(metalPricePerOunce({'XAG': value}, 'XAG', 'USD'), isNull);
    }
    expect(metalPricePerOunce({'XAU': 0.1}, 'XAG', 'USD'), isNull);
  });
}
