import 'package:hive/hive.dart';

import '../../../core/failure.dart';
import '../../../core/result.dart';
import '../../../core/stock.dart';
import '../domain/watchlist.dart';

/// Persists ALL of the user's watchlists as one `List<Map>` under a single
/// Hive key. Storing the whole collection together (rather than one key
/// per watchlist) means a create/rename/delete/reorder is always a single
/// atomic `box.put`, so there's no window where two keys could be read out
/// of sync with each other after a crash mid-write.
class WatchlistRepository {
  WatchlistRepository(this._box);

  static const String _watchlistsKey = 'watchlists';

  /// Default watchlist shown on first-ever launch, before the user has
  /// created anything themselves.
  static const String _defaultId = 'default';
  static const String _defaultName = 'My Watchlist';
  static const List<String> _defaultSymbols = <String>['RELIANCE', 'TCS', 'HDFCBANK', 'INFY', 'ICICIBANK'];

  final Box<dynamic> _box;

  Future<void> ensureSeeded() async {
    if (!_box.containsKey(_watchlistsKey)) {
      final Watchlist seed = const Watchlist(id: _defaultId, name: _defaultName, symbols: _defaultSymbols);
      await _box.put(_watchlistsKey, <Map<String, dynamic>>[seed.toMap()]);
    }
  }

  /// All watchlists, in persisted (creation) order. Any symbol that no
  /// longer exists in [StockUniverse] is silently dropped from the read
  /// path (defensive — the universe is fixed today, but this keeps reads
  /// safe if it ever changes), and duplicate symbols within one watchlist
  /// are de-duplicated defensively too.
  List<Watchlist> getAll() {
    final List<dynamic> raw = (_box.get(_watchlistsKey) as List<dynamic>?) ?? const <dynamic>[];
    return raw.map((dynamic entry) {
      final Watchlist w = Watchlist.fromMap(entry as Map<dynamic, dynamic>);
      final List<String> cleaned = <String>[];
      final Set<String> seen = <String>{};
      for (final String symbol in w.symbols) {
        if (!seen.add(symbol)) continue;
        if (StockUniverse.all.any((Stock s) => s.symbol == symbol)) cleaned.add(symbol);
      }
      return w.copyWith(symbols: cleaned);
    }).toList(growable: false);
  }

  Watchlist? getById(String id) {
    for (final Watchlist w in getAll()) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// Resolves a watchlist's symbols to live [Stock]s, in display order.
  List<Stock> stocksFor(Watchlist watchlist) =>
      watchlist.symbols.map(StockUniverse.bySymbol).toList(growable: false);

  Future<Result<bool>> _persistAll(List<Watchlist> watchlists) async {
    try {
      await _box.put(_watchlistsKey, watchlists.map((Watchlist w) => w.toMap()).toList(growable: false));
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  // ---- Watchlist-level operations (create / rename / delete) ----

  Future<Result<Watchlist>> create(String name) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err<Watchlist>(StorageFailure('Watchlist name cannot be empty.'));
    }
    final Watchlist created = Watchlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: trimmed,
      symbols: const <String>[],
    );
    final Result<bool> result = await _persistAll(<Watchlist>[...getAll(), created]);
    return result.fold<Result<Watchlist>>(
      (Failure f) => Err<Watchlist>(f),
      (bool _) => Ok<Watchlist>(created),
    );
  }

  Future<Result<bool>> rename(String watchlistId, String newName) async {
    final String trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const Err<bool>(StorageFailure('Watchlist name cannot be empty.'));
    }
    final List<Watchlist> updated = getAll()
        .map((Watchlist w) => w.id == watchlistId ? w.copyWith(name: trimmed) : w)
        .toList(growable: false);
    return _persistAll(updated);
  }

  Future<Result<bool>> delete(String watchlistId) async {
    final List<Watchlist> updated = getAll().where((Watchlist w) => w.id != watchlistId).toList(growable: false);
    return _persistAll(updated);
  }

  // ---- Stock-level operations within one watchlist ----

  Future<Result<bool>> addStock(String watchlistId, Stock stock) async {
    final List<Watchlist> all = getAll();
    final List<Watchlist> updated = all.map((Watchlist w) {
      if (w.id != watchlistId) return w;
      if (w.symbols.contains(stock.symbol)) return w; // already present in THIS watchlist, no-op
      return w.copyWith(symbols: <String>[...w.symbols, stock.symbol]);
    }).toList(growable: false);
    return _persistAll(updated);
  }

  Future<Result<bool>> removeStock(String watchlistId, Stock stock) async {
    final List<Watchlist> updated = getAll().map((Watchlist w) {
      if (w.id != watchlistId) return w;
      return w.copyWith(symbols: w.symbols.where((String s) => s != stock.symbol).toList(growable: false));
    }).toList(growable: false);
    return _persistAll(updated);
  }

  /// Moves the stock at [oldIndex] to [newIndex] within [watchlistId],
  /// matching the semantics Flutter's `ReorderableListView.onReorder`
  /// callback expects (`newIndex` is the index *after* removal from
  /// `oldIndex`).
  Future<Result<bool>> reorderStock(String watchlistId, int oldIndex, int newIndex) async {
    final List<Watchlist> all = getAll();
    final List<Watchlist> updated = all.map((Watchlist w) {
      if (w.id != watchlistId) return w;
      if (oldIndex < 0 || oldIndex >= w.symbols.length) return w;
      final List<String> symbols = List<String>.of(w.symbols);
      final String moved = symbols.removeAt(oldIndex);
      final int clampedNewIndex = newIndex.clamp(0, symbols.length).toInt();
      symbols.insert(clampedNewIndex, moved);
      return w.copyWith(symbols: symbols);
    }).toList(growable: false);
    return _persistAll(updated);
  }
}
