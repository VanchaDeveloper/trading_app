import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme.dart';
import '../../../di/service_locator.dart';
import '../domain/watchlist.dart';
import 'watchlist_detail_page.dart';
import 'watchlists_cubit.dart';

/// Feature 1 entry point: lists every watchlist the user has created.
/// Owns create/rename/delete; tapping a row drills into that watchlist's
/// stock list (`WatchlistDetailPage`).
class WatchlistsListPage extends StatelessWidget {
  const WatchlistsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WatchlistsCubit>(
      create: (_) => WatchlistsCubit(ServiceLocator.instance.watchlistRepository),
      child: const _WatchlistsListView(),
    );
  }
}

class _WatchlistsListView extends StatelessWidget {
  const _WatchlistsListView();

  Future<void> _promptCreate(BuildContext context) async {
    final WatchlistsCubit cubit = context.read<WatchlistsCubit>();
    final String? name = await _promptForName(context, title: 'New Watchlist', initialValue: '');
    if (name != null && name.trim().isNotEmpty) {
      await cubit.createWatchlist(name.trim());
    }
  }

  Future<void> _promptRename(BuildContext context, Watchlist watchlist) async {
    final WatchlistsCubit cubit = context.read<WatchlistsCubit>();
    final String? name = await _promptForName(context, title: 'Rename Watchlist', initialValue: watchlist.name);
    if (name != null && name.trim().isNotEmpty && name.trim() != watchlist.name) {
      await cubit.renameWatchlist(watchlist.id, name.trim());
    }
  }

  Future<void> _confirmDelete(BuildContext context, Watchlist watchlist) async {
    final WatchlistsCubit cubit = context.read<WatchlistsCubit>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete watchlist?'),
        content: Text('"${watchlist.name}" and its stock list will be permanently removed.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete', style: TextStyle(color: MarketColors.loss)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await cubit.deleteWatchlist(watchlist.id);
    }
  }

  Future<String?> _promptForName(BuildContext context, {required String title, required String initialValue}) {
    final TextEditingController controller = TextEditingController(text: initialValue);
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Watchlist name'),
          onSubmitted: (String value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(controller.text), child: const Text('Save')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watchlists'),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.add), tooltip: 'New watchlist', onPressed: () => _promptCreate(context)),
        ],
      ),
      body: BlocBuilder<WatchlistsCubit, WatchlistsState>(
        builder: (BuildContext context, WatchlistsState state) {
          if (state.watchlists.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('No watchlists yet.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Create a watchlist'),
                    onPressed: () => _promptCreate(context),
                  ),
                ],
              ),
            );
          }

          final WatchlistsCubit cubit = context.read<WatchlistsCubit>();

          return ListView.separated(
            itemCount: state.watchlists.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final Watchlist watchlist = state.watchlists[index];
              return ListTile(
                title: Text(watchlist.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${watchlist.symbols.length} stock${watchlist.symbols.length == 1 ? '' : 's'}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (String action) {
                    if (action == 'rename') _promptRename(context, watchlist);
                    if (action == 'delete') _confirmDelete(context, watchlist);
                  },
                  itemBuilder: (BuildContext context) => const <PopupMenuEntry<String>>[
                    PopupMenuItem<String>(value: 'rename', child: Text('Rename')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider<WatchlistsCubit>.value(
                      value: cubit,
                      child: WatchlistDetailPage(watchlistId: watchlist.id),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
