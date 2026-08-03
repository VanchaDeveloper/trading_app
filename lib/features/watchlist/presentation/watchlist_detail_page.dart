import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../../../core/theme.dart';
import '../../../di/service_locator.dart';
import '../../../widgets/stock_row.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';
import '../domain/watchlist.dart';
import 'watchlists_cubit.dart';

/// Shows one watchlist's stocks with live prices, drag-to-reorder, remove,
/// an add-stock picker, and tap-to-trade — all on a single screen (there is
/// no separate "edit mode": the drag handle and the remove control are
/// always present, exactly like a real trading app's watchlist).
///
/// Edge cases handled explicitly:
/// - Rows are keyed by symbol (`ValueKey(stock.symbol)`), not by list
///   index, so a reorder can never leave a row bound to the wrong live
///   price ticker — Flutter reconciles by key, so the widget (and its
///   `ValueListenableBuilder` subscription) moves with its stock, not with
///   its position.
/// - The add-stock picker only offers symbols not already in *this*
///   watchlist — the same symbol can still be added to a *different*
///   watchlist, since membership is tracked per watchlist, not globally.
/// - If this watchlist is deleted (e.g. from another screen) while open,
///   the screen pops itself instead of showing a broken state.
class WatchlistDetailPage extends StatelessWidget {
  const WatchlistDetailPage({super.key, required this.watchlistId});

  final String watchlistId;

  @override
  Widget build(BuildContext context) {
    final market = ServiceLocator.instance.marketDataService;

    return BlocConsumer<WatchlistsCubit, WatchlistsState>(
      listenWhen: (WatchlistsState previous, WatchlistsState current) =>
          current.byId(watchlistId) == null,
      listener: (BuildContext context, WatchlistsState state) {
        // The watchlist we're viewing no longer exists (deleted elsewhere).
        Navigator.of(context).maybePop();
      },
      builder: (BuildContext context, WatchlistsState state) {
        final Watchlist? watchlist = state.byId(watchlistId);
        if (watchlist == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final WatchlistsCubit cubit = context.read<WatchlistsCubit>();
        final List<Stock> stocks = cubit.stocksFor(watchlist);

        return Scaffold(
          appBar: AppBar(
            title: Text(watchlist.name),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add stock',
                onPressed: () => _showAddSheet(context, cubit, watchlist),
              ),
            ],
          ),
          body: stocks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('No stocks in this watchlist yet.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add a stock'),
                          onPressed: () =>
                              _showAddSheet(context, cubit, watchlist),
                        ),
                      ],
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: stocks.length,
                  onReorderItem: (int oldIndex, int newIndex) =>
                      cubit.reorderStock(watchlist.id, oldIndex, newIndex),
                  itemBuilder: (BuildContext context, int index) {
                    final Stock stock = stocks[index];
                    return Container(
                      key: ValueKey<String>(stock.symbol),
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: StockRow(
                        stock: stock,
                        tickerListenable: market.tickerFor(stock.symbol),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => BuySellTicketPage(stock: stock),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: MarketColors.loss,
                                size: 20,
                              ),
                              tooltip: 'Remove',
                              onPressed: () =>
                                  cubit.removeStock(watchlist.id, stock),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.drag_handle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _showAddSheet(
    BuildContext context,
    WatchlistsCubit cubit,
    Watchlist watchlist,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return BlocProvider<WatchlistsCubit>.value(
          value: cubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (BuildContext context, ScrollController scrollController) {
              return BlocBuilder<WatchlistsCubit, WatchlistsState>(
                builder: (BuildContext context, WatchlistsState state) {
                  final Watchlist? current = state.byId(watchlist.id);
                  final Set<String> already = (current ?? watchlist).symbols
                      .toSet();
                  final List<Stock> addable = StockUniverse.all
                      .where((Stock s) => !already.contains(s.symbol))
                      .toList(growable: false);

                  if (addable.isEmpty) {
                    return const Center(
                      child: Text(
                        'All 10 stocks are already in this watchlist.',
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: addable.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Stock stock = addable[index];
                      return ListTile(
                        title: Text(stock.symbol),
                        subtitle: Text(stock.name),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => cubit.addStock(watchlist.id, stock),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
