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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    holding.symbol,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                Text('${holding.quantity} shares', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricText(label: 'Avg cost', value: holding.averageCost.format()),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _MetricText(label: 'LTP', value: holding.currentPrice.format()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricText(label: 'Value', value: holding.currentValue.format()),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _MetricText(
                      label: 'P&L',
                      value: '$sign${holding.unrealizedPnl.format()} ($sign${holding.unrealizedPnlPercent.toStringAsFixed(2)}%)',
                      valueColor: pnlColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricText extends StatelessWidget {
  const _MetricText({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextSpan(
            text: value,
            style: AppTheme.tabularFigures.copyWith(
              fontSize: 13,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
