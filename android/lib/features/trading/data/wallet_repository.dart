import 'package:hive/hive.dart';

import '../../../core/failure.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';

/// Persists the wallet's cash balance in Hive as a single primitive int
/// (paise), avoiding any custom `TypeAdapter`/codegen — Hive can store
/// plain `int`s natively.
class WalletRepository {
  WalletRepository(this._box);

  static const String _balanceKey = 'balance_paise';
  static const int _startingBalancePaise = 100000000; // ₹10,00,000 starting cash

  final Box<dynamic> _box;

  /// Seeds the starting balance on first-ever app launch. Safe to call on
  /// every startup — it's a no-op once the key exists.
  Future<void> ensureSeeded() async {
    if (!_box.containsKey(_balanceKey)) {
      await _box.put(_balanceKey, _startingBalancePaise);
    }
  }

  Money currentBalance() {
    final int paise = (_box.get(_balanceKey) as int?) ?? _startingBalancePaise;
    return Money.fromPaise(paise);
  }

  /// Applies a signed delta to the balance (negative for a debit on BUY,
  /// positive for a credit on SELL). Callers are expected to run this
  /// inside `ServiceLocator.instance.walletOrderMutex.run(...)` alongside
  /// the corresponding order write, so the two never happen out of lock-step.
  Future<Result<Money>> applyDelta(Money delta) async {
    try {
      final Money next = currentBalance() + delta;
      await _box.put(_balanceKey, next.paise);
      return Ok<Money>(next);
    } catch (e) {
      return Err<Money>(StorageFailure(e.toString()));
    }
  }
}
