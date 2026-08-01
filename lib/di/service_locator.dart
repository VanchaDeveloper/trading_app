import 'package:hive_flutter/hive_flutter.dart';

import '../core/async_mutex.dart';
import '../core/hive_boxes.dart';
import '../data/market/market_data_service.dart';
import '../data/market/mock_market_data_service.dart';
import '../data/order_event_bus.dart';
import '../features/trading/data/order_repository.dart';
import '../features/trading/data/wallet_repository.dart';
import '../features/watchlist/data/watchlist_repository.dart';

/// A deliberately tiny, hand-written service locator. No `get_it`, no
/// codegen, no reflection — just a handful of late-initialized singletons
/// built in a known order during [ServiceLocator.init]. This keeps startup
/// wiring inspectable in one file instead of scattered across generated
/// `.g.dart` files.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late final MarketDataService marketDataService;
  late final AsyncMutex walletOrderMutex;
  late final OrderEventBus orderEventBus;
  late final WalletRepository walletRepository;
  late final OrderRepository orderRepository;
  late final WatchlistRepository watchlistRepository;

  bool _initialized = false;

  /// Opens every Hive box the app needs and constructs every singleton.
  /// Must be awaited before `runApp`.
  Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();
    final Box<dynamic> walletBox = await Hive.openBox<dynamic>(HiveBoxes.wallet);
    final Box<dynamic> ordersBox = await Hive.openBox<dynamic>(HiveBoxes.orders);
    final Box<dynamic> watchlistBox = await Hive.openBox<dynamic>(HiveBoxes.watchlist);

    marketDataService = MockMarketDataService()..start();
    walletOrderMutex = AsyncMutex();
    orderEventBus = OrderEventBus();
    walletRepository = WalletRepository(walletBox);
    orderRepository = OrderRepository(ordersBox, orderEventBus);
    watchlistRepository = WatchlistRepository(watchlistBox);

    await walletRepository.ensureSeeded();
    await watchlistRepository.ensureSeeded();

    _initialized = true;
  }
}
