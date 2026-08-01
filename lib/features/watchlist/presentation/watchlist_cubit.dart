import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../data/watchlist_repository.dart';
import '../domain/watchlist.dart';

class WatchlistState {
  const WatchlistState({
    required this.stocks,
    required this.watchlists,
    required this.selectedWatchlist,
  });

  final List<Stock> stocks;
  final List<Watchlist> watchlists;
  final Watchlist? selectedWatchlist;

  /// Stocks in the universe that are NOT already on the watchlist — used
  /// by the "Add" picker in the detail screen so a user can never add a
  /// duplicate.
  List<Stock> get addableStocks =>
      StockUniverse.all.where((Stock s) => !stocks.contains(s)).toList(growable: false);
}

/// Deliberately thin: almost all the real logic (duplicate prevention,
/// reorder-index math, persistence) lives in [WatchlistRepository], which
/// keeps it independently testable without a `BlocTest` harness. This cubit
/// just re-reads the repository after every mutation and republishes state.
class WatchlistCubit extends Cubit<WatchlistState> {
  WatchlistCubit(this._repository)
      : super(WatchlistState(
          stocks: _repository.getActiveStocks(),
          watchlists: _repository.getAll(),
          selectedWatchlist: _repository.getSelected(),
        ));

  final WatchlistRepository _repository;

  void refresh() => emit(WatchlistState(
        stocks: _repository.getActiveStocks(),
        watchlists: _repository.getAll(),
        selectedWatchlist: _repository.getSelected(),
      ));

  Future<void> create(String name) async {
    await _repository.create(name);
    refresh();
  }

  Future<void> rename(String id, String name) async {
    await _repository.rename(id, name);
    refresh();
  }

  Future<void> delete(String id) async {
    await _repository.delete(id);
    refresh();
  }

  Future<void> select(String id) async {
    await _repository.select(id);
    refresh();
  }

  Future<void> add(Stock stock) async {
    await _repository.add(stock);
    refresh();
  }

  Future<void> remove(Stock stock) async {
    await _repository.remove(stock);
    refresh();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    await _repository.reorder(oldIndex, newIndex);
    refresh();
  }
}
