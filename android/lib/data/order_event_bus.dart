import 'dart:async';

import '../../../lib/features/trading/domain/order.dart';

/// A tiny broadcast bus that fires whenever an order is successfully
/// persisted. `HoldingsCubit` subscribes to this for its order-driven
/// re-derivation trigger (see the two-trigger fix in `holdings_cubit.dart`).
///
/// Using an explicit bus (rather than having the Buy/Sell Ticket page reach
/// into a live `HoldingsCubit` directly) keeps the two features decoupled:
/// Holdings doesn't need to exist yet, or be on screen, for an order to be
/// recorded correctly — it just derives itself fresh from the order log
/// the next time it's built, and updates live if it's already listening.
class OrderEventBus {
  final StreamController<Order> _controller = StreamController<Order>.broadcast();

  Stream<Order> get onOrderExecuted => _controller.stream;

  void publish(Order order) => _controller.add(order);

  void dispose() => _controller.close();
}
