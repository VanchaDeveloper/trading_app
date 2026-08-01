import '../../../core/money.dart';

/// A current position in one symbol, derived entirely from the order
/// history plus the latest live price. This is intentionally NOT persisted
/// anywhere — persisting it would create a second source of truth that
/// could drift from the order log after a crash or a manual Hive edit.
class Holding {
  const Holding({
    required this.symbol,
    required this.quantity,
    required this.averageCost,
    required this.currentPrice,
  });

  final String symbol;
  final int quantity;

  /// Weighted average price paid per share across all BUYs still
  /// represented by [quantity] (see `holdings_calculator.dart` for the
  /// averaging rule).
  final Money averageCost;

  /// Latest live price, supplied by the caller at derivation time — this
  /// is what makes a [Holding] a live-updating view rather than a snapshot.
  final Money currentPrice;

  Money get investedAmount => averageCost * quantity;
  Money get currentValue => currentPrice * quantity;
  Money get unrealizedPnl => currentValue - investedAmount;

  double get unrealizedPnlPercent {
    if (investedAmount.paise == 0) return 0.0;
    return (unrealizedPnl.paise / investedAmount.paise) * 100;
  }

  int get pnlSign => unrealizedPnl.paise.sign;
}
