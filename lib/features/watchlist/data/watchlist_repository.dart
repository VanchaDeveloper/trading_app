import 'package:hive/hive.dart';

import '../../../core/failure.dart';
import '../../../core/result.dart';
import '../../../core/stock.dart';
import '../domain/watchlist.dart';

/// Persists the user's named watchlists as a Hive map. The repository keeps
/// the full catalog in one box and exposes the currently selected one through
/// the app's watchlist pages.
class WatchlistRepository {
  WatchlistRepository(this._box);

  static const String _selectedIdKey = 'selected_watchlist_id';
  static const String _defaultWatchlistName = 'Default';
  static const List<String> _defaultSymbols = <String>['RELI', 'TCS', 'HDFC', 'INFY', 'ICICI'];

  final Box<dynamic> _box;

  Future<void> ensureSeeded() async {
    final String id = 'default';
    if (!_box.containsKey(id)) {
      await _box.put(id, Watchlist(
        id: id,
        name: _defaultWatchlistName,
        symbols: List<String>.of(_defaultSymbols),
      ).toMap());
    }
    if (!_box.containsKey(_selectedIdKey)) {
      await _box.put(_selectedIdKey, id);
    }
  }

  List<Watchlist> getAll() {
    final List<Watchlist> result = <Watchlist>[];
    for (final dynamic raw in _box.values) {
      if (raw is Map<dynamic, dynamic>) {
        result.add(Watchlist.fromMap(raw));
      }
    }
    result.sort((Watchlist a, Watchlist b) => a.name.compareTo(b.name));
    return result;
  }

  Watchlist? getSelected() {
    final String? selectedId = _box.get(_selectedIdKey) as String?;
    if (selectedId == null) return null;
    final dynamic raw = _box.get(selectedId);
    if (raw is Map<dynamic, dynamic>) {
      return Watchlist.fromMap(raw);
    }
    return null;
  }

  List<Stock> getActiveStocks() => getSelected()?.stocks ?? <Stock>[];

  Future<Result<bool>> create(String name) async {
    final String id = DateTime.now().microsecondsSinceEpoch.toString();
    final Watchlist watchlist = Watchlist(id: id, name: name.trim(), symbols: <String>[]);
    try {
      await _box.put(id, watchlist.toMap());
      await _box.put(_selectedIdKey, id);
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> rename(String id, String name) async {
    final dynamic raw = _box.get(id);
    if (raw is! Map<dynamic, dynamic>) return const Ok<bool>(true);
    final Watchlist existing = Watchlist.fromMap(raw);
    final Watchlist updated = existing.copyWith(name: name.trim());
    try {
      await _box.put(id, updated.toMap());
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> delete(String id) async {
    try {
      await _box.delete(id);
      final String? selectedId = _box.get(_selectedIdKey) as String?;
      if (selectedId == id) {
        final List<Watchlist> remaining = getAll();
        if (remaining.isNotEmpty) {
          await _box.put(_selectedIdKey, remaining.first.id);
        }
      }
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> select(String id) async {
    try {
      await _box.put(_selectedIdKey, id);
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> add(Stock stock) async {
    final Watchlist? selected = getSelected();
    if (selected == null) return const Ok<bool>(true);
    if (selected.symbols.contains(stock.symbol)) return const Ok<bool>(true);
    final Watchlist updated = selected.copyWith(symbols: <String>[...selected.symbols, stock.symbol]);
    try {
      await _box.put(selected.id, updated.toMap());
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> remove(Stock stock) async {
    final Watchlist? selected = getSelected();
    if (selected == null) return const Ok<bool>(true);
    final Watchlist updated = selected.copyWith(symbols: <String>[...selected.symbols]..removeWhere((String symbol) => symbol == stock.symbol));
    try {
      await _box.put(selected.id, updated.toMap());
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }

  Future<Result<bool>> reorder(int oldIndex, int newIndex) async {
    final Watchlist? selected = getSelected();
    if (selected == null) return const Ok<bool>(true);
    final List<String> current = List<String>.of(selected.symbols);
    if (oldIndex < 0 || oldIndex >= current.length) return const Ok<bool>(true);
    final String moved = current.removeAt(oldIndex);
    final int clampedNewIndex = newIndex.clamp(0, current.length).toInt();
    current.insert(clampedNewIndex, moved);
    final Watchlist updated = selected.copyWith(symbols: current);
    try {
      await _box.put(selected.id, updated.toMap());
      return const Ok<bool>(true);
    } catch (e) {
      return Err<bool>(StorageFailure(e.toString()));
    }
  }
}
