import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../domain/order.dart';

class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final bool isBuy = order.side == OrderSide.buy;
    final Color accent = isBuy ? MarketColors.gain : MarketColors.loss;

    return Scaffold(
      appBar: AppBar(title: const Text('Order Confirmed')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check_circle, color: accent, size: 64),
              const SizedBox(height: 16),
              Text(
                '${isBuy ? 'Bought' : 'Sold'} ${order.quantity} ${order.symbol}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text('@ ${order.pricePerShare.format()} per share', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Text('Total: ${order.totalAmount.format()}', style: AppTheme.tabularFiguresLarge),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
