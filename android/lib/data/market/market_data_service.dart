import 'package:flutter/foundation.dart';

import 'price_tick.dart';

/// The single source of live price data for the whole app. Every feature
/// (Watchlist, Live Prices, Buy/Sell Ticket, Holdings) depends only on this
/// interface — never on `MockMarketDataService` directly — so the mock
/// engine can be swapped for a real websocket feed later with zero changes
/// to feature code.
abstract class MarketDataService {
  /// Starts the feed (idempotent — calling twice is a no-op).
  void start();

  /// Stops the feed and releases the underlying timer.
  void dispose();

  /// A per-symbol notifier that fires on every price update for that
  /// symbol only. UI widgets should listen to exactly the symbols they
  /// display, so a Live Prices row for RELI never rebuilds when TCS ticks.
  ValueListenable<PriceTick> tickerFor(String symbol);

  /// The latest known tick for a symbol, read synchronously without
  /// subscribing. Used by one-shot reads (e.g. computing an order total).
  PriceTick latestTick(String symbol);
}
