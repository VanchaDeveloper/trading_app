/// Base type for every domain-level error in the app. Kept sealed-ish via a
/// private constructor pattern so all failures are exhaustively enumerable
/// at the call site (switch on runtimeType, or use the getters below).
abstract class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The order quantity was zero, negative, or not a whole number of shares.
class InvalidQuantityFailure extends Failure {
  const InvalidQuantityFailure() : super('Quantity must be a positive whole number of shares.');
}

/// A BUY order whose total cost exceeds the wallet's available balance.
class InsufficientFundsFailure extends Failure {
  const InsufficientFundsFailure() : super('Insufficient funds to complete this purchase.');
}

/// A SELL order for more shares than are currently held.
class InsufficientHoldingsFailure extends Failure {
  const InsufficientHoldingsFailure() : super('You do not own enough shares to sell that quantity.');
}

/// The symbol referenced does not exist in the fixed stock universe.
class UnknownSymbolFailure extends Failure {
  const UnknownSymbolFailure(String symbol) : super('Unknown symbol: $symbol');
}

/// The market price for a symbol was unavailable (feed not yet warmed up).
class PriceUnavailableFailure extends Failure {
  const PriceUnavailableFailure() : super('Live price is not yet available. Please try again.');
}

/// A persistence (Hive) read/write failed unexpectedly.
class StorageFailure extends Failure {
  const StorageFailure(String detail) : super('Storage error: $detail');
}
