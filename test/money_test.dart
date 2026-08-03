import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/core/money.dart';

void main() {
  group('Money', () {
    test('formats with Indian-style digit grouping', () {
      expect(const Money.fromRupees(1234).format(), '\u20B91,234.00');
      expect(const Money.fromRupees(1234567).format(), '\u20B912,34,567.00');
    });

    test('parse round-trips decimal rupee strings exactly', () {
      expect(Money.parse('1234.56').paise, 123456);
      expect(Money.parse('-42.05').paise, -4205);
    });

    test('arithmetic stays exact — no floating-point drift', () {
      // The classic 0.1 + 0.2 != 0.3 double bug must NOT reproduce here,
      // since Money is backed by integer paise, not double rupees.
      final Money a = Money.parse('0.10');
      final Money b = Money.parse('0.20');
      expect((a + b).paise, 30);
      expect((a + b), Money.parse('0.30'));
    });

    test('multiplying by a share quantity is exact', () {
      final Money price = Money.parse('284.55');
      expect((price * 7).paise, 284_55 * 7);
    });
  });
}
