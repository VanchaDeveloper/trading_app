import '../../../core/money.dart';

enum OrderSide { buy, sell }

/// An immutable record of one executed trade. Orders are append-only —
/// there is no "edit order" concept anywhere in the app — which is what
/// makes deriving Holdings from the full order history safe (see
/// `holdings_calculator.dart`).
class Order {
  const Order({
    required this.id,
    required this.symbol,
    required this.side,
    required this.quantity,
    required this.pricePerShare,
    required this.executedAt,
  });

  final String id;
  final String symbol;
  final OrderSide side;
  final int quantity;
  final Money pricePerShare;
  final DateTime executedAt;

  Money get totalAmount => pricePerShare * quantity;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'symbol': symbol,
        'side': side.name,
        'quantity': quantity,
        'pricePerSharePaise': pricePerShare.paise,
        'executedAtMillis': executedAt.millisecondsSinceEpoch,
      };

  factory Order.fromMap(Map<dynamic, dynamic> map) {
    return Order(
      id: map['id'] as String,
      symbol: map['symbol'] as String,
      side: (map['side'] as String) == 'buy' ? OrderSide.buy : OrderSide.sell,
      quantity: map['quantity'] as int,
      pricePerShare: Money.fromPaise(map['pricePerSharePaise'] as int),
      executedAt: DateTime.fromMillisecondsSinceEpoch(map['executedAtMillis'] as int),
    );
  }
}
