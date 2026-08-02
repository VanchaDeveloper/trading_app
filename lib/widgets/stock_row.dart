import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/stock.dart';
import '../core/theme.dart';
import '../data/market/price_tick.dart';

/// A single price row shown in both the Watchlist and Live Prices screens.
/// Kept in one shared widget so those two features can never visually
/// diverge (e.g. one showing percent change and the other not).
///
/// Subscribes only to the [ValueListenable] for its own symbol, so — per
/// the engine's per-symbol-notifier design — this row rebuilds only when
/// its own stock ticks, not on every other symbol's update.
class StockRow extends StatelessWidget {
  const StockRow({
    super.key,
    required this.stock,
    required this.tickerListenable,
    this.onTap,
    this.trailing,
  });

  final Stock stock;
  final ValueListenable<PriceTick> tickerListenable;
  final VoidCallback? onTap;

  /// Optional extra widget (e.g. a drag handle in the reorderable
  /// Watchlist detail screen) rendered at the far right.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PriceTick>(
      valueListenable: tickerListenable,
      builder: (BuildContext context, PriceTick tick, _) {
        final Color changeColor = MarketColors.forChange(tick.changeSign);
        final String sign = tick.changeSign > 0 ? '+' : '';

        return RepaintBoundary(
          child: TweenAnimationBuilder<double>(
            key: ValueKey<DateTime>(tick.timestamp),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            builder:
                (BuildContext context, double animationValue, Widget? child) {
                  final double flashOpacity = (1 - animationValue).clamp(
                    0.0,
                    1.0,
                  );
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: tick.changeSign == 0
                          ? Colors.transparent
                          : changeColor.withOpacity(flashOpacity * 0.18),
                    ),
                    child: child,
                  );
                },
            child: Semantics(
              button: onTap != null,
              label:
                  '${stock.symbol} ${stock.name}, ${tick.price.format()}, ${tick.changePercent.toStringAsFixed(2)} percent ${tick.changeSign >= 0 ? 'up' : 'down'}',
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              stock.symbol,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stock.name,
                              style: Theme.of(context).textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text(
                            tick.price.format(),
                            style: AppTheme.tabularFigures,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$sign${tick.changeAmount.format()} (${sign}${tick.changePercent.toStringAsFixed(2)}%)',
                            style: AppTheme.tabularFigures.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: changeColor,
                            ),
                          ),
                        ],
                      ),
                      if (trailing != null) ...<Widget>[
                        const SizedBox(width: 8),
                        trailing!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
