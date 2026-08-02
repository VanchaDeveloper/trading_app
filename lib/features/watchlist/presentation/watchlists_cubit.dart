import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../data/watchlist_repository.dart';
import '../domain/watchlist.dart';

class WatchlistsState {
  const WatchlistsState({required this.watchlists});

  final List<Watchlist> watchlists;

  Watchlist? byId(String id) {
    for (final Watchlist w in watchlists) {
      if (w.id == id) return w;
    }
    return null;
  }
}

/// Deliberately one cubit for the whole feature (rather than one cubit per
/// watchlist): every screen — the top-level watchlists list AND every
/// individual watchlist's detail screen — reads from the same
/// `WatchlistsState`, so there is exactly one in-memory source of truth
/// that always matches what's persisted. A rename or a stock add in one
/// screen is immediately visible anywhere else that's showing the same
/// data, with no cross-cubit sync to get wrong.
class WatchlistsCubit extends Cubit<WatchlistsState> {
  WatchlistsCubit(this._repository) : super(WatchlistsState(watchlists: _repository.getAll()));

  final WatchlistRepository _repository;

  void _refresh() => emit(WatchlistsState(watchlists: _repository.getAll()));

  List<Stock> stocksFor(Watchlist watchlist) => _repository.stocksFor(watchlist);

  Future<void> createWatchlist(String name) async {
    await _repository.create(name);
    _refresh();
  }

  Future<void> renameWatchlist(String watchlistId, String newName) async {
    await _repository.rename(watchlistId, newName);
    _refresh();
  }

  Future<void> deleteWatchlist(String watchlistId) async {
    await _repository.delete(watchlistId);
    _refresh();
  }

  Future<void> addStock(String watchlistId, Stock stock) async {
    await _repository.addStock(watchlistId, stock);
    _refresh();
  }

  Future<void> removeStock(String watchlistId, Stock stock) async {
    await _repository.removeStock(watchlistId, stock);
    _refresh();
  }

  Future<void> reorderStock(String watchlistId, int oldIndex, int newIndex) async {
    await _repository.reorderStock(watchlistId, oldIndex, newIndex);
    _refresh();
  }
}
