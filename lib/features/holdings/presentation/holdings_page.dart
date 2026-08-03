import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../../../di/service_locator.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';
import '../domain/holdings_sort.dart';
import 'holding_row.dart';
import 'holdings_cubit.dart';
import 'holdings_summary_card.dart';

/// Feature 4: Holdings. Wraps the page in its own `BlocProvider` so the
/// cubit's lifecycle (and its throttled reorder timer) is tied to this page
/// being on the widget tree, not to the app's lifetime.
class HoldingsPage extends StatelessWidget {
  const HoldingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HoldingsCubit>(
      create: (_) => HoldingsCubit(
        orderRepository: ServiceLocator.instance.orderRepository,
        marketDataService: ServiceLocator.instance.marketDataService,
        orderEventBus: ServiceLocator.instance.orderEventBus,
      ),
      child: const _HoldingsView(),
    );
  }
}

class _HoldingsView extends StatelessWidget {
  const _HoldingsView();

  @override
  Widget build(BuildContext context) {
    final market = ServiceLocator.instance.marketDataService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Holdings'),
        actions: <Widget>[
          BlocBuilder<HoldingsCubit, HoldingsState>(
            buildWhen: (HoldingsState previous, HoldingsState current) =>
                previous.sortMode != current.sortMode,
            builder: (BuildContext context, HoldingsState state) {
              return PopupMenuButton<HoldingsSortMode>(
                icon: const Icon(Icons.sort),
                tooltip: 'Sort: ${state.sortMode.label}',
                onSelected: (HoldingsSortMode mode) =>
                    context.read<HoldingsCubit>().setSortMode(mode),
                itemBuilder: (BuildContext context) => HoldingsSortMode.values
                    .map(
                      (HoldingsSortMode mode) =>
                          PopupMenuItem<HoldingsSortMode>(
                            value: mode,
                            child: Row(
                              children: <Widget>[
                                if (mode == state.sortMode)
                                  const Icon(Icons.check, size: 18)
                                else
                                  const SizedBox(width: 18),
                                const SizedBox(width: 8),
                                Text(mode.label),
                              ],
                            ),
                          ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
      // Only rebuilds when the STRUCTURAL holdings list changes (a trade
      // executes) or the throttled reorder/sort-mode fires — never on a
      // raw price tick, since each row's own price display is handled by
      // its own independent subscription below.
      body: BlocBuilder<HoldingsCubit, HoldingsState>(
        builder: (BuildContext context, HoldingsState state) {
          if (state.holdings.isEmpty) {
            return const Center(
              child: Text('No holdings yet. Buy a stock to see it here.'),
            );
          }

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: HoldingsSummaryCard(
                  holdings: state.holdings,
                  market: market,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: state.holdings.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final holding = state.holdings[index];
                    return HoldingRow(
                      key: ValueKey<String>(holding.symbol),
                      holding: holding,
                      tickerListenable: market.tickerFor(holding.symbol),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BuySellTicketPage(
                            stock: StockUniverse.bySymbol(holding.symbol),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
