import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/failure.dart';
import '../../../core/money.dart';
import '../../../core/result.dart';
import '../../../core/stock.dart';
import '../../../core/theme.dart';
import '../../../data/market/price_tick.dart';
import '../../../di/service_locator.dart';
import '../domain/order.dart';
import '../domain/trade_validator.dart';
import 'order_confirmation_page.dart';

/// Feature 3: Buy/Sell Ticket. A single quantity field drives a live
/// preview of the order total; Confirm runs the full validate-then-execute
/// sequence inside the shared wallet/order mutex so a double-tap or a race
/// with another in-flight order can never corrupt the wallet balance.
///
/// The live price and projected total are wrapped in a
/// `ValueListenableBuilder` bound to this stock's ticker, so they update on
/// every tick while the ticket is open — not just when the user happens to
/// interact with the form. The price actually used to EXECUTE the order is
/// always re-read fresh at the moment Confirm is pressed (see `_onConfirm`),
/// so it can never be stale relative to what's displayed either.
class BuySellTicketPage extends StatefulWidget {
  const BuySellTicketPage({super.key, required this.stock});

  final Stock stock;

  @override
  State<BuySellTicketPage> createState() => _BuySellTicketPageState();
}

class _BuySellTicketPageState extends State<BuySellTicketPage> {
  OrderSide _side = OrderSide.buy;
  final TextEditingController _quantityController = TextEditingController(text: '1');
  String? _errorText;
  bool _submitting = false;
  late final ValueListenable<PriceTick> _ticker;

  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

  @override
  void initState() {
    super.initState();
    _ticker = ServiceLocator.instance.marketDataService.tickerFor(widget.stock.symbol);
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    setState(() {
      _errorText = null;
      _submitting = true;
    });

    final sl = ServiceLocator.instance;
    final int quantity = _quantity;
    final OrderSide side = _side;
    final String symbol = widget.stock.symbol;
    // Always re-read the live price at the moment of submission — this is
    // the price the order actually executes at, independent of whatever
    // was last painted on screen.
    final Money pricePerShare = sl.marketDataService.latestTick(symbol).price;

    // The entire read-validate-write sequence runs inside the mutex so no
    // other order for this or any other symbol can interleave and observe
    // a stale wallet balance or holdings quantity.
    final Result<Order> result = await sl.walletOrderMutex.run<Result<Order>>(() async {
      final Money walletBalance = sl.walletRepository.currentBalance();
      final int heldQuantity = sl.orderRepository.getForSymbol(symbol).fold<int>(
            0,
            (int qty, Order o) => o.side == OrderSide.buy ? qty + o.quantity : qty - o.quantity,
          );

      final Result<Order> validation = const TradeValidator().validate(
        symbol: symbol,
        side: side,
        quantity: quantity,
        pricePerShare: pricePerShare,
        currentWalletBalance: walletBalance,
        currentHeldQuantity: heldQuantity,
        generateOrderId: () => DateTime.now().microsecondsSinceEpoch.toString(),
        now: () => DateTime.now(),
      );

      if (validation is Err<Order>) {
        return validation;
      }
      final Order order = (validation as Ok<Order>).value;
      final Money delta = order.side == OrderSide.buy ? -order.totalAmount : order.totalAmount;
      final Result<Money> walletResult = await sl.walletRepository.applyDelta(delta);
      if (walletResult.isErr) {
        return Err<Order>(walletResult.failureOrNull!);
      }
      return sl.orderRepository.append(order);
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (Failure failure) => setState(() => _errorText = failure.message),
      (Order order) => Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OrderConfirmationPage(order: order)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.stock.symbol} \u00b7 ${widget.stock.name}')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Live price + projected total: rebuilds on every tick via this
            // ValueListenableBuilder, independent of any user interaction
            // with the rest of the form.
            ValueListenableBuilder<PriceTick>(
              valueListenable: _ticker,
              builder: (BuildContext context, PriceTick tick, _) {
                final Money total = tick.price * (_quantity < 0 ? 0 : _quantity);
                final Color changeColor = MarketColors.forChange(tick.changeSign);
                final String sign = tick.changeSign > 0 ? '+' : '';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Live price', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(tick.price.format(), style: AppTheme.tabularFiguresLarge),
                        const SizedBox(width: 8),
                        Text(
                          '$sign${tick.changeAmount.format()} (${sign}${tick.changePercent.toStringAsFixed(2)}%)',
                          style: AppTheme.tabularFigures.copyWith(fontSize: 13, color: changeColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Order total', style: Theme.of(context).textTheme.bodySmall),
                        Text(total.format(), style: AppTheme.tabularFigures),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            SegmentedButton<OrderSide>(
              segments: const <ButtonSegment<OrderSide>>[
                ButtonSegment<OrderSide>(value: OrderSide.buy, label: Text('Buy')),
                ButtonSegment<OrderSide>(value: OrderSide.sell, label: Text('Sell')),
              ],
              selected: <OrderSide>{_side},
              onSelectionChanged: (Set<OrderSide> selection) => setState(() => _side = selection.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                border: const OutlineInputBorder(),
                errorText: _quantityController.text.isNotEmpty && _quantity <= 0
                    ? 'Enter a whole number greater than zero.'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(_errorText!, style: const TextStyle(color: MarketColors.loss)),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: _submitting || _quantity <= 0 ? null : _onConfirm,
              child: _submitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_side == OrderSide.buy ? 'Confirm Buy' : 'Confirm Sell'),
            ),
          ],
        ),
      ),
    );
  }
}
