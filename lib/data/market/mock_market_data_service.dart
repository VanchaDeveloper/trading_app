import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/money.dart';
import '../../core/stock.dart';
import 'market_data_service.dart';
import 'price_tick.dart';

/// A fully offline mock implementation of [MarketDataService].
///
/// Design notes:
/// - **Single [Timer] heartbeat**: one periodic timer drives every symbol's
///   update, rather than one timer per symbol. This keeps the engine to a
///   single scheduling point (easy to reason about, easy to pause/resume)
///   and avoids 10 independent timers drifting out of phase with each other.
/// - **Per-symbol [ValueNotifier]s**: each symbol gets its own
///   `ValueNotifier<PriceTick>` so a widget listening to RELI only rebuilds
///   on RELI ticks, never on the other 9 symbols' ticks. This is the crux of
///   keeping Watchlist/Live Prices rebuild-cheap with `ValueListenableBuilder`.
/// - **Clamped random walk**: each tick nudges the price by a small random
///   percentage of the *previous tick's* price (not the seed price), so
///   movement compounds realistically, but is clamped to +/-15% away from
///   the seed price so the mock feed can never wander into an absurd
///   (e.g. negative or 100x) price over a long session.
class MockMarketDataService implements MarketDataService {
  MockMarketDataService({
    Random? random,
    Duration tickInterval = const Duration(milliseconds: 200),
  }) : _random = random ?? Random(),
       _tickInterval = tickInterval;

  Duration _tickInterval;

  /// Max fractional move per tick, e.g. 0.006 = up to 0.6% per tick.
  static const double _maxStepFraction = 0.006;

  /// Max fractional distance from seed price in either direction.
  static const double _maxDriftFraction = 0.15;

  final Random _random;
  final Map<String, ValueNotifier<PriceTick>> _notifiers =
      <String, ValueNotifier<PriceTick>>{};
  Timer? _timer;
  bool _started = false;

  @override
  void start() {
    if (_started) return;
    _started = true;

    for (final Stock stock in StockUniverse.all) {
      _notifiers[stock.symbol] = ValueNotifier<PriceTick>(
        PriceTick.initial(stock.symbol, stock.seedPrice),
      );
    }

    _timer = Timer.periodic(_tickInterval, (_) => _tickAll());
  }

  void _tickAll() {
    for (final Stock stock in StockUniverse.all) {
      final ValueNotifier<PriceTick> notifier = _notifiers[stock.symbol]!;
      final PriceTick previous = notifier.value;
      notifier.value = _nextTick(stock, previous);
    }
  }

  PriceTick _nextTick(Stock stock, PriceTick previous) {
    final int seedPaise = stock.seedPrice.paise;
    final int previousPaise = previous.price.paise;

    // Random step as a fraction of the current price, in [-max, +max].
    final double stepFraction =
        (_random.nextDouble() * 2 - 1) * _maxStepFraction;
    final int stepPaise = (previousPaise * stepFraction).round();

    int nextPaise = previousPaise + stepPaise;

    // Clamp to +/-maxDriftFraction of the seed price so the walk can't
    // run away over a long session.
    final int minPaise = (seedPaise * (1 - _maxDriftFraction)).round();
    final int maxPaise = (seedPaise * (1 + _maxDriftFraction)).round();
    nextPaise = nextPaise.clamp(minPaise, maxPaise).toInt();

    // Never let a stock go to zero or below regardless of clamp math.
    if (nextPaise < 1) nextPaise = 1;

    final Money nextPrice = Money.fromPaise(nextPaise);
    final Money change = nextPrice - stock.seedPrice;

    return PriceTick(
      symbol: stock.symbol,
      price: nextPrice,
      previousClose: stock.seedPrice,
      changeAmount: change,
      changeSign: change.paise.sign,
      timestamp: DateTime.now(),
    );
  }

  @override
  void setTickInterval(Duration tickInterval) {
    if (tickInterval <= Duration.zero) return;
    _tickInterval = tickInterval;
    if (_started) {
      _timer?.cancel();
      _timer = Timer.periodic(_tickInterval, (_) => _tickAll());
    }
  }

  @override
  ValueListenable<PriceTick> tickerFor(String symbol) {
    final ValueNotifier<PriceTick>? notifier = _notifiers[symbol];
    if (notifier == null) {
      throw ArgumentError('Unknown symbol: $symbol. Did you call start()?');
    }
    return notifier;
  }

  @override
  PriceTick latestTick(String symbol) => tickerFor(symbol).value;

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    for (final ValueNotifier<PriceTick> notifier in _notifiers.values) {
      notifier.dispose();
    }
    _notifiers.clear();
    _started = false;
  }
}
