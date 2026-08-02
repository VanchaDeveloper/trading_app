import 'package:flutter/material.dart';

import '../../../core/stock.dart';
import '../../../data/market/market_data_service.dart';
import '../../../di/service_locator.dart';
import '../../../widgets/stock_row.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';

/// Feature 2: Live Prices. Shows every stock in the fixed universe with its
/// current price and change, ticking live off the shared [MarketDataService].
/// Deliberately the thinnest feature — no persistence, no domain logic —
/// since its only job is to visualize the feed.
class LivePricesPage extends StatelessWidget {
  const LivePricesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final MarketDataService market = ServiceLocator.instance.marketDataService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Prices'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Tick rate debug',
            icon: const Icon(Icons.speed_outlined),
            onPressed: () => _showTickRateDialog(context, market),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: StockUniverse.all.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          final stock = StockUniverse.all[index];
          return StockRow(
            stock: stock,
            tickerListenable: market.tickerFor(stock.symbol),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BuySellTicketPage(stock: stock),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showTickRateDialog(
    BuildContext context,
    MarketDataService market,
  ) async {
    const double currentMs = 200;
    double selectedMs = currentMs;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder:
              (BuildContext context, void Function(void Function()) setState) {
                return AlertDialog(
                  title: const Text('Tick rate debug'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Text('Adjust the mock feed cadence live.'),
                      const SizedBox(height: 12),
                      Slider(
                        value: selectedMs,
                        min: 50,
                        max: 1000,
                        divisions: 19,
                        label: '${selectedMs.round()} ms',
                        onChanged: (double value) {
                          setState(() => selectedMs = value);
                        },
                      ),
                      Text('Current tick interval: ${selectedMs.round()} ms'),
                    ],
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        market.setTickInterval(
                          Duration(milliseconds: selectedMs.round()),
                        );
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('Apply'),
                    ),
                  ],
                );
              },
        );
      },
    );
  }
}
