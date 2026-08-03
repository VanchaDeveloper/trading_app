import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../data/market/market_data_service.dart';
import '../../../data/order_event_bus.dart';
import '../../trading/data/order_repository.dart';
import '../../trading/domain/order.dart';
import '../domain/holding.dart';
import '../domain/holdings_calculator.dart';
import '../domain/holdings_sort.dart';

class HoldingsState {
  const HoldingsState({
    required this.holdings,
    required this.totalCurrentValue,
    required this.totalInvested,
    required this.sortMode,
  });

  factory HoldingsState.empty() => const HoldingsState(
    holdings: <Holding>[],
    totalCurrentValue: Money.zero,
    totalInvested: Money.zero,
    sortMode: HoldingsSortMode.pnlDesc,
  );

  final List<Holding> holdings;
  final Money totalCurrentValue;
  final Money totalInvested;
  final HoldingsSortMode sortMode;

  Money get totalPnl => totalCurrentValue - totalInvested;
}

/// Holdings react to three kinds of events, kept deliberately separate:
///
/// 1. **Order-driven re-derivation** (rare, structural, immediate): whenever
///    an order executes, quantities/average cost can change, or a symbol can
///    enter/leave the list. Re-runs `HoldingsCalculator.derive` immediately
///    — the user just confirmed a trade and expects Holdings to reflect it
///    with no delay.
///
/// 2. **Throttled reorder** (frequent price ticks, but only the ORDER of
///    rows needs periodic recomputation): re-ranking 10 rows by P&L or
///    value only needs to happen a few times a second at most — a human
///    can't perceive reordering faster than that, and re-sorting on every
///    single tick would mean touching the whole list far more often than
///    necessary. This is the only thing this cubit still polls for.
///
/// 3. **Per-row live display** is deliberately NOT this cubit's job anymore.
///    Each `HoldingRow` subscribes directly to its own symbol's ticker (the
///    same pattern `StockRow` uses in Live Prices/Watchlist), so LTP and
///    P&L text update on every tick, immediately, without going through
///    this cubit or rebuilding sibling rows. The cubit only decides WHICH
///    holdings exist, their qty/avg cost, and — throttled — what ORDER to
///    render them in.
class HoldingsCubit extends Cubit<HoldingsState> {
  HoldingsCubit({
    required this._orderRepository,
    required this._marketDataService,
    required OrderEventBus orderEventBus,
    this._calculator = const HoldingsCalculator(),
    Duration reorderThrottle = const Duration(milliseconds: 700),
  }) : super(HoldingsState.empty()) {
    _deriveFromOrders(); // initial load
    // TRIGGER 1 — order-driven: fires immediately, no throttling.
    _orderSub = orderEventBus.onOrderExecuted.listen(
      (Order _) => _deriveFromOrders(),
    );
    // TRIGGER 2 — throttled reorder only (see class doc above).
    _reorderTimer = Timer.periodic(
      reorderThrottle,
      (_) => _reorderByLatestPrices(),
    );
  }

  final OrderRepository _orderRepository;
  final MarketDataService _marketDataService;
  final HoldingsCalculator _calculator;
  late final Timer _reorderTimer;
  late final StreamSubscription<Order> _orderSub;

  void _deriveFromOrders() {
    final orders = _orderRepository.getAll();
    final Map<String, Money> latestPrices = <String, Money>{
      for (final order in orders)
        order.symbol: _marketDataService.latestTick(order.symbol).price,
    };
    final holdings = _calculator.derive(orders, latestPrices);
    emit(_toState(holdings, state.sortMode));
  }

  /// Refreshes each holding's `currentPrice` from the live feed purely to
  /// determine current sort rank (P&L/value can only be ranked correctly
  /// with a fresh price) and re-sorts. Does NOT touch the order log, so it
  /// can never contradict a just-executed order.
  void _reorderByLatestPrices() {
    if (state.holdings.isEmpty) return;
    if (state.sortMode == HoldingsSortMode.symbolAsc) {
      return; // order is price-independent; nothing to do
    }
    final List<Holding> refreshed = state.holdings.map((Holding h) {
      final Money latestPrice = _marketDataService.latestTick(h.symbol).price;
      return Holding(
        symbol: h.symbol,
        quantity: h.quantity,
        averageCost: h.averageCost,
        currentPrice: latestPrice,
      );
    }).toList();
    emit(_toState(refreshed, state.sortMode));
  }

  /// User-initiated sort change — always immediate, never throttled, since
  /// it's a direct response to a tap, not routine price noise.
  void setSortMode(HoldingsSortMode mode) =>
      emit(_toState(state.holdings, mode));

  HoldingsState _toState(List<Holding> holdings, HoldingsSortMode sortMode) {
    final List<Holding> sorted = holdings.sortedBy(sortMode);
    Money totalCurrent = Money.zero;
    Money totalInvested = Money.zero;
    for (final Holding h in sorted) {
      totalCurrent += h.currentValue;
      totalInvested += h.investedAmount;
    }
    return HoldingsState(
      holdings: sorted,
      totalCurrentValue: totalCurrent,
      totalInvested: totalInvested,
      sortMode: sortMode,
    );
  }

  @override
  Future<void> close() {
    _reorderTimer.cancel();
    unawaited(_orderSub.cancel());
    return super.close();
  }
}
