import '../../core/money.dart';

/// A single price observation for a symbol. `changeSign` and `changeAmount`
/// are precomputed here (at the point the tick is produced) rather than
/// recomputed by every widget that displays it — this guarantees the
/// Watchlist, Live Prices, and Holdings screens can never disagree about
/// whether a stock is "up" or "down" at a given instant.
class PriceTick {
  const PriceTick({
    required this.symbol,
    required this.price,
    required this.previousClose,
    required this.changeAmount,
    required this.changeSign,
  });

  factory PriceTick.initial(String symbol, Money seedPrice) {
    return PriceTick(
      symbol: symbol,
      price: seedPrice,
      previousClose: seedPrice,
      changeAmount: Money.zero,
      changeSign: 0,
    );
  }

  final String symbol;
  final Money price;
  final Money previousClose;

  /// Always `price - previousClose`; positive means up, negative means down.
  final Money changeAmount;

  /// -1, 0, or 1 — mirrors `changeAmount.paise.sign`, kept as a separate
  /// field so consumers doing color lookups don't need to touch `Money`.
  final int changeSign;

  /// Percentage change vs previous close, e.g. 1.23 means +1.23%.
  /// Returns 0.0 if previousClose is zero (should never happen in practice
  /// since every stock has a positive seed price).
  double get changePercent {
    if (previousClose.paise == 0) return 0.0;
    return (changeAmount.paise / previousClose.paise) * 100;
  }
}
