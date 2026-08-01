import '../../../core/failure.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';
import 'order.dart';

/// Pure, side-effect-free validation of a proposed trade. This is the
/// correctness-critical piece of the whole app: it is the only place that
/// decides whether a BUY can afford itself or a SELL is covered by existing
/// holdings. Every check here returns a [Result], never throws, so the
/// presentation layer can render every failure as ordinary UI state.
class TradeValidator {
  const TradeValidator();

  /// Validates a proposed order. Does NOT touch storage — callers pass in
  /// the current wallet balance and current held quantity so this stays a
  /// pure function and is trivially unit-testable.
  Result<Order> validate({
    required String symbol,
    required OrderSide side,
    required int quantity,
    required Money pricePerShare,
    required Money currentWalletBalance,
    required int currentHeldQuantity,
    required String Function() generateOrderId,
    required DateTime Function() now,
  }) {
    if (quantity <= 0) {
      return const Err<Order>(InvalidQuantityFailure());
    }

    final Order proposed = Order(
      id: generateOrderId(),
      symbol: symbol,
      side: side,
      quantity: quantity,
      pricePerShare: pricePerShare,
      executedAt: now(),
    );

    if (side == OrderSide.buy) {
      if (proposed.totalAmount > currentWalletBalance) {
        return const Err<Order>(InsufficientFundsFailure());
      }
    } else {
      if (quantity > currentHeldQuantity) {
        return const Err<Order>(InsufficientHoldingsFailure());
      }
    }

    return Ok<Order>(proposed);
  }
}
