import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../core/theme.dart';
import '../../../data/market/price_tick.dart';
import '../domain/holding.dart';

/// Shows one holding's symbol, quantity, avg cost, LTP, current value, and
/// P&L (₹ and %). Subscribes directly to this symbol's own ticker — the
/// same per-symbol-notifier pattern `StockRow` uses — so LTP/current
/// value/P&L update immediately on every tick for THIS row only, without
/// going through `HoldingsCubit` or touching any sibling row. Quantity and
/// average cost come from [holding] (order-driven, effectively static
/// between trades).
class HoldingRow extends StatelessWidget {
  const HoldingRow({super.key, required this.holding, required this.tickerListenable, this.onTap});

  final Holding holding;
  final ValueListenable<PriceTick> tickerListenable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PriceTick>(
      valueListenable: tickerListenable,
      builder: (BuildContext context, PriceTick tick, _) {
        final Money ltp = tick.price;
        final Money currentValue = ltp * holding.quantity;
        final Money pnl = currentValue - holding.investedAmount;
        final double pnlPercent =
            holding.investedAmount.paise == 0 ? 0.0 : (pnl.paise / holding.investedAmount.paise) * 100;
        final int pnlSign = pnl.paise.sign;
        final Color pnlColor = MarketColors.forChange(pnlSign);
        final String sign = pnlSign > 0 ? '+' : '';

        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(holding.symbol, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        '${holding.quantity} shares \u00b7 avg ${holding.averageCost.format()}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('LTP ${ltp.format()}', style: AppTheme.tabularFigures.copyWith(fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(currentValue.format(), style: AppTheme.tabularFigures),
                    const SizedBox(height: 2),
                    Text(
                      '$sign${pnl.format()} ($sign${pnlPercent.toStringAsFixed(2)}%)',
                      style: AppTheme.tabularFigures.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: pnlColor),
                    ),
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
