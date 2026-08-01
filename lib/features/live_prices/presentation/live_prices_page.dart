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
      appBar: AppBar(title: const Text('Live Prices')),
      body: ListView.separated(
        itemCount: StockUniverse.all.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
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
}
