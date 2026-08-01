import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../../../core/theme.dart';
import '../../../di/service_locator.dart';
import '../../../widgets/stock_row.dart';
import 'watchlist_cubit.dart';

/// Reorderable add/remove screen for the watchlist. Edge cases handled
/// explicitly:
/// - Removing the last item leaves an empty (not broken) reorderable list.
/// - Adding is only offered for symbols not already present (see
///   `WatchlistState.addableStocks`), so duplicates are structurally
///   impossible rather than merely discouraged.
/// - Reorder indices are translated through the repository's `reorder`,
///   which itself accounts for Flutter's "newIndex is post-removal" quirk.
class WatchlistDetailPage extends StatelessWidget {
  const WatchlistDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final market = ServiceLocator.instance.marketDataService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Watchlist'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add stock',
            onPressed: () => _showAddSheet(context),
          ),
        ],
      ),
      body: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (BuildContext context, WatchlistState state) {
          if (state.stocks.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('No stocks on your watchlist yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add a stock'),
                      onPressed: () => _showAddSheet(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: state.stocks.length,
            onReorder: (int oldIndex, int newIndex) {
              // ReorderableListView passes newIndex as if the item hadn't
              // been removed yet; the repository expects the same
              // convention and normalizes internally.
              context.read<WatchlistCubit>().reorder(oldIndex, newIndex);
            },
            itemBuilder: (BuildContext context, int index) {
              final Stock stock = state.stocks[index];
              return Container(
                key: ValueKey<String>(stock.symbol),
                color: Theme.of(context).scaffoldBackgroundColor,
                child: StockRow(
                  stock: stock,
                  tickerListenable: market.tickerFor(stock.symbol),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.close, color: MarketColors.loss, size: 20),
                        tooltip: 'Remove',
                        onPressed: () => context.read<WatchlistCubit>().remove(stock),
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
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final WatchlistCubit cubit = context.read<WatchlistCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return BlocProvider<WatchlistCubit>.value(
          value: cubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.3,
            maxChildSize: 0.9,
            expand: false,
            builder: (BuildContext context, ScrollController scrollController) {
              return BlocBuilder<WatchlistCubit, WatchlistState>(
                builder: (BuildContext context, WatchlistState state) {
                  final List<Stock> addable = state.addableStocks;
                  if (addable.isEmpty) {
                    return const Center(child: Text('All stocks are already on your watchlist.'));
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: addable.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      final Stock stock = addable[index];
                      return ListTile(
                        title: Text(stock.symbol),
                        subtitle: Text(stock.name),
                        trailing: const Icon(Icons.add_circle_outline),
                        onTap: () => cubit.add(stock),
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
