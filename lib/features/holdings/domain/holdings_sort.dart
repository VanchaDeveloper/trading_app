import 'holding.dart';

enum HoldingsSortMode { pnlDesc, valueDesc, symbolAsc }

extension HoldingsSortModeLabel on HoldingsSortMode {
  String get label {
    switch (this) {
      case HoldingsSortMode.pnlDesc:
        return 'P&L (high to low)';
      case HoldingsSortMode.valueDesc:
        return 'Current value (high to low)';
      case HoldingsSortMode.symbolAsc:
        return 'Symbol (A–Z)';
    }
  }
}

extension HoldingsSorting on List<Holding> {
  /// Returns a NEW sorted list (does not mutate this one) — callers always
  /// hold an immutable snapshot, which keeps state comparisons and Bloc
  /// change detection straightforward.
  List<Holding> sortedBy(HoldingsSortMode mode) {
    final List<Holding> copy = List<Holding>.of(this);
    switch (mode) {
      case HoldingsSortMode.pnlDesc:
        copy.sort((Holding a, Holding b) => b.unrealizedPnl.paise.compareTo(a.unrealizedPnl.paise));
      case HoldingsSortMode.valueDesc:
        copy.sort((Holding a, Holding b) => b.currentValue.paise.compareTo(a.currentValue.paise));
      case HoldingsSortMode.symbolAsc:
        copy.sort((Holding a, Holding b) => a.symbol.compareTo(b.symbol));
    }
    return copy;
  }
}
