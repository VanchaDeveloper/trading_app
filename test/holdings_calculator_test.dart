import 'package:flutter_test/flutter_test.dart';

import 'package:trading_app/core/money.dart';
import 'package:trading_app/features/holdings/domain/holding.dart';
import 'package:trading_app/features/holdings/domain/holdings_calculator.dart';
import 'package:trading_app/features/trading/domain/order.dart';

void main() {
  group('HoldingsCalculator', () {
    const HoldingsCalculator calculator = HoldingsCalculator();

    test(
      'computes weighted average cost using truncating integer division',
      () {
        final List<Order> orders = <Order>[
          Order(
            id: '1',
            symbol: 'RELI',
            side: OrderSide.buy,
            quantity: 2,
            pricePerShare: const Money.fromPaise(1000),
            executedAt: DateTime(2026, 1, 1),
          ),
          Order(
            id: '2',
            symbol: 'RELI',
            side: OrderSide.buy,
            quantity: 1,
            pricePerShare: const Money.fromPaise(3000),
            executedAt: DateTime(2026, 1, 2),
          ),
        ];

        final List<Holding> result = calculator.derive(orders, <String, Money>{
          'RELI': const Money.fromPaise(2500),
        });

        expect(result, hasLength(1));
        expect(result.first.averageCost.paise, equals(1666));
        expect(result.first.currentPrice.paise, equals(2500));
      },
    );

    test('drops fully exited positions', () {
      final List<Order> orders = <Order>[
        Order(
          id: '1',
          symbol: 'RELI',
          side: OrderSide.buy,
          quantity: 2,
          pricePerShare: const Money.fromPaise(1000),
          executedAt: DateTime(2026, 1, 1),
        ),
        Order(
          id: '2',
          symbol: 'RELI',
          side: OrderSide.sell,
          quantity: 2,
          pricePerShare: const Money.fromPaise(1100),
          executedAt: DateTime(2026, 1, 3),
        ),
      ];

      final List<Holding> result = calculator.derive(orders, <String, Money>{
        'RELI': const Money.fromPaise(1100),
      });

      expect(result, isEmpty);
    });
  });
}
