import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../../../di/service_locator.dart';
import '../../../widgets/stock_row.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';
import '../domain/watchlist.dart';
import 'watchlist_cubit.dart';
import 'watchlist_detail_page.dart';

/// Feature 1: Watchlist. Shows the user's customized, reorderable list of
/// stocks with live prices. Tapping a row opens the Buy/Sell ticket;
/// tapping "Edit" opens the reorderable add/remove screen.
class WatchlistPage extends StatelessWidget {
  const WatchlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WatchlistCubit>(
      create: (_) => WatchlistCubit(ServiceLocator.instance.watchlistRepository),
      child: const _WatchlistView(),
    );
  }
}

class _WatchlistView extends StatelessWidget {
  const _WatchlistView();

  @override
  Widget build(BuildContext context) {
    final market = ServiceLocator.instance.marketDataService;

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<WatchlistCubit, WatchlistState>(
          builder: (BuildContext context, WatchlistState state) {
            final String title = state.selectedWatchlist?.name ?? 'Watchlist';
            return Text(title);
          },
        ),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.list_outlined),
            tooltip: 'Manage watchlists',
            onPressed: () => _showWatchlistManager(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit watchlist',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider<WatchlistCubit>.value(
                  value: context.read<WatchlistCubit>(),
                  child: const WatchlistDetailPage(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<WatchlistCubit, WatchlistState>(
        builder: (BuildContext context, WatchlistState state) {
          if (state.stocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Your watchlist is empty.'),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add stocks'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider<WatchlistCubit>.value(
                          value: context.read<WatchlistCubit>(),
                          child: const WatchlistDetailPage(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: state.stocks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Stock stock = state.stocks[index];
              return StockRow(
                stock: stock,
                tickerListenable: market.tickerFor(stock.symbol),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => BuySellTicketPage(stock: stock)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showWatchlistManager(BuildContext context) {
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
            builder: (BuildContext innerContext, ScrollController scrollController) {
              return BlocBuilder<WatchlistCubit, WatchlistState>(
                builder: (BuildContext innerContext, WatchlistState state) {
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Watchlists',
                              style: Theme.of(innerContext).textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            onPressed: () => _promptCreateWatchlist(innerContext),
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Create watchlist',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (state.watchlists.isEmpty)
                        const Text('No watchlists yet.')
                      else
                        ...state.watchlists.map((Watchlist watchlist) {
                          final bool isSelected = state.selectedWatchlist?.id == watchlist.id;
                          return ListTile(
                            title: Text(watchlist.name),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                if (isSelected) const Icon(Icons.check),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  tooltip: 'Rename watchlist',
                                  onPressed: () => _promptRenameWatchlist(innerContext, watchlist),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete watchlist',
                                  onPressed: () => _confirmDeleteWatchlist(innerContext, watchlist),
                                ),
                              ],
                            ),
                            onTap: () {
                              cubit.select(watchlist.id);
                              Navigator.of(sheetContext).pop();
                            },
                            subtitle: Text('${watchlist.symbols.length} stocks'),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _promptCreateWatchlist(BuildContext context) async {
    final TextEditingController controller = TextEditingController();
    final WatchlistCubit cubit = context.read<WatchlistCubit>();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Create watchlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Watchlist name'),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;
    await cubit.create(result);
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _promptRenameWatchlist(BuildContext context, Watchlist watchlist) async {
    final TextEditingController controller = TextEditingController(text: watchlist.name);
    final WatchlistCubit cubit = context.read<WatchlistCubit>();
    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Rename watchlist'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Watchlist name'),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) return;
    await cubit.rename(watchlist.id, result);
  }

  Future<void> _confirmDeleteWatchlist(BuildContext context, Watchlist watchlist) async {
    final WatchlistCubit cubit = context.read<WatchlistCubit>();
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete watchlist?'),
          content: Text('Delete “${watchlist.name}”? This cannot be undone.'),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    await cubit.delete(watchlist.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}
