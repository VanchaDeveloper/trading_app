import 'package:flutter_test/flutter_test.dart';
import 'package:trading_app/core/money.dart';
import 'package:trading_app/features/holdings/domain/holdings_calculator.dart';
import 'package:trading_app/features/trading/domain/order.dart';

void main() {
  const HoldingsCalculator calculator = HoldingsCalculator();

  test('a buy then a partial sell keeps average cost unchanged', () {
    final orders = <Order>[
      Order(
        id: '1',
        symbol: 'TCS',
        side: OrderSide.buy,
        quantity: 10,
        pricePerShare: const Money.fromRupees(100),
        executedAt: DateTime(2026, 1, 1),
      ),
      Order(
        id: '2',
        symbol: 'TCS',
        side: OrderSide.buy,
        quantity: 10,
        pricePerShare: const Money.fromRupees(200),
        executedAt: DateTime(2026, 1, 2),
      ),
      Order(
        id: '3',
        symbol: 'TCS',
        side: OrderSide.sell,
        quantity: 5,
        pricePerShare: const Money.fromRupees(250),
        executedAt: DateTime(2026, 1, 3),
      ),
    ];

    final holdings = calculator.derive(orders, <String, Money>{
      'TCS': const Money.fromRupees(300),
    });

    expect(holdings, hasLength(1));
    expect(holdings.first.quantity, 15);
    // (10*100 + 10*200) / 20 = 150 — the sell realizes P&L, it doesn't
    // change the remaining shares' cost basis.
    expect(holdings.first.averageCost, const Money.fromRupees(150));
  });

  test('a position that nets to zero is dropped from holdings entirely', () {
    final orders = <Order>[
      Order(
        id: '1',
        symbol: 'ITC',
        side: OrderSide.buy,
        quantity: 5,
        pricePerShare: const Money.fromRupees(50),
        executedAt: DateTime(2026, 1, 1),
      ),
      Order(
        id: '2',
        symbol: 'ITC',
        side: OrderSide.sell,
        quantity: 5,
        pricePerShare: const Money.fromRupees(60),
        executedAt: DateTime(2026, 1, 2),
      ),
    ];

    final holdings = calculator.derive(orders, <String, Money>{
      'ITC': const Money.fromRupees(60),
    });

    expect(holdings, isEmpty);
  });
}
