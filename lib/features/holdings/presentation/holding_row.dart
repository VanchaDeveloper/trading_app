import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../domain/holding.dart';

class HoldingRow extends StatelessWidget {
  const HoldingRow({super.key, required this.holding, this.onTap});

  final Holding holding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color pnlColor = MarketColors.forChange(holding.pnlSign);
    final String sign = holding.pnlSign > 0 ? '+' : '';

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
                    '${holding.quantity} shares · avg ${holding.averageCost.format()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(holding.currentValue.format(), style: AppTheme.tabularFigures),
                const SizedBox(height: 2),
                Text(
                  '$sign${holding.unrealizedPnl.format()} ($sign${holding.unrealizedPnlPercent.toStringAsFixed(2)}%)',
                  style: AppTheme.tabularFigures.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: pnlColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
