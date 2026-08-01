import '../../../core/money.dart';
import '../../trading/domain/order.dart';
import 'holding.dart';

/// Pure function that folds the entire order history into the current set
/// of open [Holding]s, using the weighted-average-cost method:
///
/// - A BUY increases quantity and recomputes average cost as a weighted
///   blend of the old position's cost and the new shares' cost.
/// - A SELL decreases quantity but leaves average cost unchanged (standard
///   average-cost accounting — a sell realizes P&L, it doesn't change the
///   remaining shares' cost basis).
/// - A symbol whose quantity nets to zero is dropped from the result
///   entirely (it is no longer "held").
///
/// Being a pure function of `List<Order>` (no side effects, no storage
/// reads) is what makes this safe to re-run on every order-list change
/// without any incremental-update bookkeeping to get wrong.
class HoldingsCalculator {
  const HoldingsCalculator();

  /// [latestPrices] maps symbol -> current live price, used only to fill in
  /// `Holding.currentPrice` for the P&L display; it does not affect
  /// quantity or average-cost math at all.
  List<Holding> derive(List<Order> orders, Map<String, Money> latestPrices) {
    final Map<String, int> quantityBySymbol = <String, int>{};
    final Map<String, Money> avgCostBySymbol = <String, Money>{};

    // Orders must be processed in execution order for average-cost blending
    // to be correct.
    final List<Order> chronological = List<Order>.of(orders)
      ..sort((Order a, Order b) => a.executedAt.compareTo(b.executedAt));

    for (final Order order in chronological) {
      final int existingQty = quantityBySymbol[order.symbol] ?? 0;
      final Money existingAvgCost = avgCostBySymbol[order.symbol] ?? Money.zero;

      if (order.side == OrderSide.buy) {
        final int newQty = existingQty + order.quantity;
        final Money existingCostBasis = existingAvgCost * existingQty;
        final Money incomingCostBasis = order.pricePerShare * order.quantity;
        final Money newCostBasis = existingCostBasis + incomingCostBasis;
        final Money newAvgCost = newQty == 0
            ? Money.zero
            : Money.fromPaise((newCostBasis.paise / newQty).round());

        quantityBySymbol[order.symbol] = newQty;
        avgCostBySymbol[order.symbol] = newAvgCost;
      } else {
        final int newQty = existingQty - order.quantity;
        // Average cost is unchanged by a sell; only quantity drops.
        quantityBySymbol[order.symbol] = newQty < 0 ? 0 : newQty;
      }
    }

    final List<Holding> holdings = <Holding>[];
    quantityBySymbol.forEach((String symbol, int quantity) {
      if (quantity <= 0) return; // fully exited positions are not "held"
      holdings.add(Holding(
        symbol: symbol,
        quantity: quantity,
        averageCost: avgCostBySymbol[symbol] ?? Money.zero,
        currentPrice: latestPrices[symbol] ?? avgCostBySymbol[symbol] ?? Money.zero,
      ));
    });

    holdings.sort((Holding a, Holding b) => a.symbol.compareTo(b.symbol));
    return holdings;
  }
}
