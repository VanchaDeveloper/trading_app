import 'package:flutter_test/flutter_test.dart';

import 'package:trading_app/core/money.dart';
import 'package:trading_app/features/trading/domain/order.dart';
import 'package:trading_app/features/trading/domain/trade_validator.dart';
import 'package:trading_app/core/failure.dart';
import 'package:trading_app/core/result.dart';

void main() {
  group('Money', () {
    test('parses rupee strings into exact paise', () {
      expect(Money.parse('1234.56').paise, equals(123456));
      expect(Money.parse('-12.34').paise, equals(-1234));
    });

    test('formats using grouped rupees and two decimal places', () {
      expect(const Money.fromPaise(123456).format(), equals('₹1,234.56'));
      expect(const Money.fromPaise(-123456).format(), equals('-₹1,234.56'));
    });
  });

  group('TradeValidator', () {
    const TradeValidator validator = TradeValidator();

    test('rejects non-positive quantities', () {
      final Result<Order> result = validator.validate(
        symbol: 'RELI',
        side: OrderSide.buy,
        quantity: 0,
        pricePerShare: const Money.fromPaise(1000),
        currentWalletBalance: const Money.fromPaise(5000),
        currentHeldQuantity: 0,
        generateOrderId: () => 'id-1',
        now: () => DateTime(2026, 1, 1),
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<InvalidQuantityFailure>());
    });

    test('rejects buy orders that exceed wallet balance', () {
      final Result<Order> result = validator.validate(
        symbol: 'RELI',
        side: OrderSide.buy,
        quantity: 8,
        pricePerShare: const Money.fromPaise(1000),
        currentWalletBalance: const Money.fromPaise(7000),
        currentHeldQuantity: 0,
        generateOrderId: () => 'id-2',
        now: () => DateTime(2026, 1, 1),
      );

      expect(result.isErr, isTrue);
      expect(result.failureOrNull, isA<InsufficientFundsFailure>());
    });

    test('accepts a valid buy order', () {
      final Result<Order> result = validator.validate(
        symbol: 'RELI',
        side: OrderSide.buy,
        quantity: 3,
        pricePerShare: const Money.fromPaise(1000),
        currentWalletBalance: const Money.fromPaise(5000),
        currentHeldQuantity: 0,
        generateOrderId: () => 'id-3',
        now: () => DateTime(2026, 1, 1),
      );

      expect(result.isOk, isTrue);
      final Order order = result.valueOrNull!;
      expect(order.symbol, equals('RELI'));
      expect(order.quantity, equals(3));
    });
  });
}
