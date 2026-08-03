import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../data/market/market_data_service.dart';
import '../domain/holding.dart';

/// Total invested / current value / P&L across every holding, updating on
/// every relevant tick — not throttled, and not tied to the row list's own
/// rebuild cadence.
///
/// This is what keeps the summary always equal to the sum of the rows
/// "at any moment": rather than reading a periodically-refreshed total off
/// `HoldingsState` (which would lag the same throttle used for reordering),
/// this widget listens directly to the SAME per-symbol price notifiers the
/// rows themselves listen to, via `Listenable.merge`, and recomputes the
/// sum fresh on every fire. Structural changes (a holding added/removed)
/// are picked up via `didUpdateWidget`, which rebuilds the merged
/// subscription whenever the *set* of held symbols changes.
class HoldingsSummaryCard extends StatefulWidget {
  const HoldingsSummaryCard({super.key, required this.holdings, required this.market});

  final List<Holding> holdings;
  final MarketDataService market;

  @override
  State<HoldingsSummaryCard> createState() => _HoldingsSummaryCardState();
}

class _HoldingsSummaryCardState extends State<HoldingsSummaryCard> {
  late Listenable _merged;

  @override
  void initState() {
    super.initState();
    _merged = _mergedListenable();
  }

  @override
  void didUpdateWidget(covariant HoldingsSummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Set<String> oldSymbols = oldWidget.holdings.map((Holding h) => h.symbol).toSet();
    final Set<String> newSymbols = widget.holdings.map((Holding h) => h.symbol).toSet();
    if (!setEquals(oldSymbols, newSymbols)) {
      _merged = _mergedListenable();
    }
  }

  Listenable _mergedListenable() {
    return Listenable.merge(
      widget.holdings.map((Holding h) => widget.market.tickerFor(h.symbol)).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _merged,
      builder: (BuildContext context, Widget? _) {
        Money totalInvested = Money.zero;
        Money totalCurrent = Money.zero;
        for (final Holding h in widget.holdings) {
          final Money ltp = widget.market.latestTick(h.symbol).price;
          totalInvested += h.investedAmount;
          totalCurrent += ltp * h.quantity;
        }
        final Money totalPnl = totalCurrent - totalInvested;
        final double totalPnlPercent = totalInvested.paise == 0 ? 0.0 : (totalPnl.paise / totalInvested.paise) * 100;
        final Color pnlColor = MarketColors.forChange(totalPnl.paise.sign);
        final String sign = totalPnl.paise.sign > 0 ? '+' : '';

        return Card(
          color: AppTheme.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Portfolio Value', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(totalCurrent.format(), style: AppTheme.tabularFiguresLarge),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      '$sign${totalPnl.format()} ($sign${totalPnlPercent.toStringAsFixed(2)}%)',
                      style: AppTheme.tabularFigures.copyWith(color: pnlColor),
                    ),
                    const Spacer(),
                    Text('Invested ${totalInvested.format()}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
