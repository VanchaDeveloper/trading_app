import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/money.dart';
import '../../../data/market/market_data_service.dart';
import '../../../data/order_event_bus.dart';
import '../../trading/data/order_repository.dart';
import '../../trading/domain/order.dart';
import '../domain/holding.dart';
import '../domain/holdings_calculator.dart';

enum HoldingsSort { pnl, value, symbol }

class HoldingsState {
  const HoldingsState({
    required this.holdings,
    required this.totalCurrentValue,
    required this.totalInvested,
    required this.sortBy,
  });

  factory HoldingsState.empty() => const HoldingsState(
        holdings: <Holding>[],
        totalCurrentValue: Money.zero,
        totalInvested: Money.zero,
        sortBy: HoldingsSort.pnl,
      );

  final List<Holding> holdings;
  final Money totalCurrentValue;
  final Money totalInvested;
  final HoldingsSort sortBy;

  Money get totalPnl => totalCurrentValue - totalInvested;
}

/// Holdings must react to two fundamentally different kinds of events, and
/// — this is the crux of the "two-trigger fix" — they must be handled
/// *separately*, not folded into one combined listener:
///
/// 1. **Order-driven re-derivation** (rare, structural): whenever an order
///    is executed, quantities and average cost can change, or a symbol can
///    enter/leave the holdings list entirely. This must re-run the full
///    `HoldingsCalculator.derive` immediately — there is no acceptable
///    delay, since the user just confirmed a trade and expects Holdings to
///    reflect it instantly.
///
/// 2. **Price-driven refresh** (frequent, cosmetic): every market tick
///    (every ~2s, across up to 10 symbols) only changes `currentPrice` and
///    therefore P&L — never quantity or average cost. Re-deriving from
///    scratch on every single tick would be wasteful and would cause
///    Holdings to rebuild far more often than a human can perceive.
///    Instead this is throttled to a fixed cadence and only recomputes the
///    price/P&L fields (and re-sorts if the sort key is P&L-based),
///    without touching the order log at all.
///
/// Mixing these two into one handler was the bug this fix addresses: naively
/// re-deriving on *every* tick made the "just bought, list should update
/// immediately" case indistinguishable from routine price noise, and caused
/// either janky over-rendering or (if throttled too aggressively) a stale
/// list right after a trade.
class HoldingsCubit extends Cubit<HoldingsState> {
  HoldingsCubit({
    required OrderRepository orderRepository,
    required MarketDataService marketDataService,
    required OrderEventBus orderEventBus,
    HoldingsCalculator calculator = const HoldingsCalculator(),
    Duration priceRefreshThrottle = const Duration(milliseconds: 800),
  })  : _orderRepository = orderRepository,
        _marketDataService = marketDataService,
        _calculator = calculator,
        super(HoldingsState.empty()) {
    _deriveFromOrders(); // initial load
    // TRIGGER 1 — order-driven: fires immediately (no throttling) whenever
    // any order is executed anywhere in the app.
    _orderSub = orderEventBus.onOrderExecuted.listen((Order _) => _deriveFromOrders());
    // TRIGGER 2 — price-driven: fires on a fixed cadence, independent of
    // trigger 1, and only touches price/P&L fields.
    _priceRefreshTimer = Timer.periodic(priceRefreshThrottle, (_) => _refreshPricesOnly());
  }

  final OrderRepository _orderRepository;
  final MarketDataService _marketDataService;
  final HoldingsCalculator _calculator;
  late final Timer _priceRefreshTimer;
  late final StreamSubscription<Order> _orderSub;

  void setSort(HoldingsSort sortBy) {
    if (state.sortBy == sortBy) return;
    emit(_toState(state.holdings, sortBy: sortBy));
  }

  void _deriveFromOrders() {
    final orders = _orderRepository.getAll();
    final Map<String, Money> latestPrices = <String, Money>{
      for (final order in orders) order.symbol: _marketDataService.latestTick(order.symbol).price,
    };
    final holdings = _calculator.derive(orders, latestPrices);
    emit(_toState(holdings, sortBy: state.sortBy));
  }

  /// TRIGGER 2 — throttled, price-only refresh. Deliberately does NOT
  /// touch the order repository at all, so it can never contradict a
  /// just-executed order; it only refreshes `currentPrice` for the symbols
  /// already known to be held.
  void _refreshPricesOnly() {
    if (state.holdings.isEmpty) return;
    final List<Holding> refreshed = state.holdings.map((Holding h) {
      final Money latestPrice = _marketDataService.latestTick(h.symbol).price;
      return Holding(
        symbol: h.symbol,
        quantity: h.quantity,
        averageCost: h.averageCost,
        currentPrice: latestPrice,
      );
    }).toList();
    emit(_toState(refreshed, sortBy: state.sortBy));
  }

  HoldingsState _toState(List<Holding> holdings, {required HoldingsSort sortBy}) {
    final List<Holding> sorted = _sortHoldings(List<Holding>.of(holdings), sortBy);
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
      sortBy: sortBy,
    );
  }

  List<Holding> _sortHoldings(List<Holding> holdings, HoldingsSort sortBy) {
    switch (sortBy) {
      case HoldingsSort.pnl:
        holdings.sort((Holding a, Holding b) => b.unrealizedPnl.paise.compareTo(a.unrealizedPnl.paise));
        break;
      case HoldingsSort.value:
        holdings.sort((Holding a, Holding b) => b.currentValue.paise.compareTo(a.currentValue.paise));
        break;
      case HoldingsSort.symbol:
        holdings.sort((Holding a, Holding b) => a.symbol.compareTo(b.symbol));
        break;
    }
    return holdings;
  }

  @override
  Future<void> close() {
    _priceRefreshTimer.cancel();
    unawaited(_orderSub.cancel());
    return super.close();
  }
}
