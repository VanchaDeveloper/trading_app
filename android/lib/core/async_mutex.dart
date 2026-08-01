import 'dart:async';

/// A minimal mutual-exclusion lock for async critical sections.
///
/// Why this exists: wallet debit/credit and order-list append must happen
/// as one atomic unit. If a user double-taps "Confirm" (or two different
/// order flows race), two `run()` calls could interleave — e.g. both read
/// the same wallet balance before either writes it back, letting a user
/// spend money they don't have. Wrapping the whole read-check-write
/// sequence in [AsyncMutex.run] guarantees only one such sequence executes
/// at a time, in FIFO order.
///
/// This is intentionally tiny (no external package) since a single-isolate
/// Flutter app only needs to serialize `Future`-based critical sections, not
/// real OS-level threads.
class AsyncMutex {
  Future<void> _tail = Future<void>.value();

  /// Runs [criticalSection] exclusively: it will not start until every
  /// previously-queued critical section on this mutex has finished, and no
  /// later one will start until this one finishes.
  Future<T> run<T>(Future<T> Function() criticalSection) {
    final Completer<void> myTurnDone = Completer<void>();
    final Future<void> previousTail = _tail;
    _tail = myTurnDone.future;

    return previousTail.then((_) async {
      try {
        return await criticalSection();
      } finally {
        myTurnDone.complete();
      }
    });
  }
}
