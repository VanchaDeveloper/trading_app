import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trading_app/main.dart';

void main() {
  testWidgets('Trading App renders a provided home widget', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const TradingApp(
        home: Scaffold(body: Center(child: Text('Trading App'))),
      ),
    );

    expect(find.text('Trading App'), findsOneWidget);
  });
}
