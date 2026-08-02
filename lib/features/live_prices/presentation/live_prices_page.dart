import 'package:flutter/material.dart';

import '../../../core/stock.dart';
import '../../../data/market/market_data_service.dart';
import '../../../data/market/mock_market_data_service.dart';
import '../../../di/service_locator.dart';
import '../../../widgets/stock_row.dart';
import '../../trading/presentation/buy_sell_ticket_page.dart';

/// Feature 2: Live Prices. Shows every stock in the fixed universe with its
/// current price and change, ticking live off the shared [MarketDataService].
/// Deliberately the thinnest feature — no persistence, no domain logic —
/// since its only job is to visualize the feed.
///
/// Also hosts a debug tick-rate control (the speed icon in the app bar) so
/// the feed's configurability is something a reviewer can actually
/// exercise at runtime — including cranking it to a stress-test rate — not
/// just a constant that would require a recompile to change.
class LivePricesPage extends StatefulWidget {
  const LivePricesPage({super.key});

  @override
  State<LivePricesPage> createState() => _LivePricesPageState();
}

class _TickRatePreset {
  const _TickRatePreset(this.label, this.interval);
  final String label;
  final Duration interval;
}

class _LivePricesPageState extends State<LivePricesPage> {
  static const List<_TickRatePreset> _presets = <_TickRatePreset>[
    _TickRatePreset('Normal (1 tick/2s per stock)', Duration(seconds: 2)),
    _TickRatePreset('Fast (2 ticks/s per stock)', Duration(milliseconds: 500)),
    _TickRatePreset('Stress (5 ticks/s per stock \u2248 50/s overall)', Duration(milliseconds: 200)),
    _TickRatePreset('Extreme (10 ticks/s per stock \u2248 100/s overall)', Duration(milliseconds: 100)),
  ];

  @override
  Widget build(BuildContext context) {
    final MarketDataService market = ServiceLocator.instance.marketDataService;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Prices'),
        actions: <Widget>[
          PopupMenuButton<Duration>(
            icon: const Icon(Icons.speed),
            tooltip: 'Tick rate: ${_labelFor(market.tickInterval)}',
            onSelected: (Duration interval) {
              market.setTickInterval(interval);
              setState(() {}); // refresh the tooltip/subtitle for the new rate
            },
            itemBuilder: (BuildContext context) => _presets
                .map((_TickRatePreset p) => PopupMenuItem<Duration>(value: p.interval, child: Text(p.label)))
                .toList(growable: false),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Feed rate: ${_labelFor(market.tickInterval)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
      ),
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

  String _labelFor(Duration interval) {
    for (final _TickRatePreset preset in _presets) {
      if (preset.interval == interval) return preset.label;
    }
    if (interval == MockMarketDataService.defaultTickInterval) {
      return _presets.first.label;
    }
    return '${interval.inMilliseconds}ms/tick';
  }
}
