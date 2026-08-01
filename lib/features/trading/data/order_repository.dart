import 'package:hive/hive.dart';

import '../../../core/failure.dart';
import '../../../core/result.dart';
import '../../../data/order_event_bus.dart';
import '../domain/order.dart';

/// Persists the append-only order log in Hive. Each entry is stored as a
/// plain `Map<String, dynamic>` (via `Order.toMap`/`Order.fromMap`) so no
/// custom `TypeAdapter` or `build_runner` codegen is needed — Hive can
/// store nested primitive maps natively.
///
/// Orders are keyed by their own `id` inside the box, which makes `getAll`
/// stable and lets us keep the box itself as the single source of truth
/// (no separate in-memory cache to go stale).
class OrderRepository {
  OrderRepository(this._box, this._eventBus);

  final Box<dynamic> _box;
  final OrderEventBus _eventBus;

  /// All executed orders, oldest first. Holdings are derived by folding
  /// over this list (see `holdings_calculator.dart`) — there is no
  /// separately-persisted holdings table, so it can never drift out of
  /// sync with the order history.
  List<Order> getAll() {
    final List<Order> orders = _box.values
        .map((dynamic raw) => Order.fromMap(raw as Map<dynamic, dynamic>))
        .toList(growable: false);
    orders.sort((Order a, Order b) => a.executedAt.compareTo(b.executedAt));
    return orders;
  }

  List<Order> getForSymbol(String symbol) =>
      getAll().where((Order o) => o.symbol == symbol).toList(growable: false);

  Future<Result<Order>> append(Order order) async {
    try {
      await _box.put(order.id, order.toMap());
      _eventBus.publish(order);
      return Ok<Order>(order);
    } catch (e) {
      return Err<Order>(StorageFailure(e.toString()));
    }
  }
}
