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

  int get _quantity => int.tryParse(_quantityController.text) ?? 0;

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
    final ValueListenable<PriceTick> tickerListenable = ServiceLocator.instance.marketDataService.tickerFor(widget.stock.symbol);

    return ValueListenableBuilder<PriceTick>(
      valueListenable: tickerListenable,
      builder: (BuildContext context, PriceTick tick, _) {
        final Money pricePerShare = tick.price;
        final Money total = pricePerShare * (_quantity < 0 ? 0 : _quantity);

        return Scaffold(
          appBar: AppBar(title: Text('${widget.stock.symbol} \u00b7 ${widget.stock.name}')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Live price', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(pricePerShare.format(), style: AppTheme.tabularFiguresLarge),
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
                  decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Order total', style: Theme.of(context).textTheme.bodySmall),
                    Text(total.format(), style: AppTheme.tabularFigures),
                  ],
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
      },
    );
  }
}
