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
///
/// On every tick that actually moves the price, this row briefly flashes
/// its background — green if the price just went up, red if it just went
/// down — independent of the persistent change/% text color (which
/// reflects cumulative change since previous close, not this instant's
/// direction). The flash is driven by its own [AnimationController] rather
/// than `setState`, so the pulse repaints only this row's background, not
/// the row's text/layout and never any other row.
class StockRow extends StatefulWidget {
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
  State<StockRow> createState() => _StockRowState();
}

class _StockRowState extends State<StockRow> with SingleTickerProviderStateMixin {
  late final AnimationController _flashController;
  int? _lastPricePaise;
  Color _flashColor = MarketColors.neutral;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  /// Compares this tick's price to the previous one (NOT the day's
  /// previous-close) and, if it moved, restarts the flash animation with
  /// the appropriate direction color. Deliberately does not call
  /// `setState` — the controller's own listeners (consumed via
  /// `AnimatedBuilder` below) are what drive the repaint, so a flash never
  /// triggers a full row rebuild.
  void _registerTick(PriceTick tick) {
    final int paise = tick.price.paise;
    if (_lastPricePaise != null && paise != _lastPricePaise) {
      _flashColor = paise > _lastPricePaise! ? MarketColors.gain : MarketColors.loss;
      _flashController.forward(from: 0);
    }
    _lastPricePaise = paise;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PriceTick>(
      valueListenable: widget.tickerListenable,
      builder: (BuildContext context, PriceTick tick, _) {
        _registerTick(tick);

        final Color changeColor = MarketColors.forChange(tick.changeSign);
        final String sign = tick.changeSign > 0 ? '+' : '';

        final Widget content = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.stock.symbol,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.stock.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(tick.price.format(), style: AppTheme.tabularFigures),
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
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        );

        return InkWell(
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _flashController,
            // `child` is the row content, built once per tick, and reused
            // across every animation frame of the flash — only the
            // Container's color is recomputed each frame.
            child: content,
            builder: (BuildContext context, Widget? child) {
              // Fades from full flash intensity down to transparent.
              final double intensity = 1 - _flashController.value;
              return Container(
                color: _flashColor.withOpacity(0.16 * intensity),
                child: child,
              );
            },
          ),
        );
      },
    );
  }
}
