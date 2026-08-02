import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/stock.dart';
import '../../../core/theme.dart';
import '../../../di/service_locator.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';
import 'holding_row.dart';
import 'holdings_cubit.dart';

/// Feature 4: Holdings. Wraps the page in its own `BlocProvider` so the
/// cubit's lifecycle (and its throttled price-refresh timer) is tied to
/// this page being on the widget tree, not to the app's lifetime.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Holdings')),
      body: BlocBuilder<HoldingsCubit, HoldingsState>(
        builder: (BuildContext context, HoldingsState state) {
          if (state.holdings.isEmpty) {
            return const Center(
              child: Text('No holdings yet. Buy a stock to see it here.'),
            );
          }

          final Color pnlColor = MarketColors.forChange(state.totalPnl.paise.sign);
          final String sign = state.totalPnl.paise.sign > 0 ? '+' : '';

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text('Portfolio Value', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(state.totalCurrentValue.format(), style: AppTheme.tabularFiguresLarge),
                        const SizedBox(height: 4),
                        Text(
                          '$sign${state.totalPnl.format()}',
                          style: AppTheme.tabularFigures.copyWith(color: pnlColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: state.holdings.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final holding = state.holdings[index];
                    return HoldingRow(
                      holding: holding,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BuySellTicketPage(stock: StockUniverse.bySymbol(holding.symbol)),
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
