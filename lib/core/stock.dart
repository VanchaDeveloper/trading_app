import 'money.dart';

/// A single tradable instrument. Immutable static metadata only — live price
/// state lives in the market data engine, never here.
class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.seedPrice,
  });

  final String symbol;
  final String name;

  /// Opening/seed price used to initialize the mock feed engine.
  final Money seedPrice;

  @override
  bool operator ==(Object other) => other is Stock && other.symbol == symbol;

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() => symbol;
}

/// The fixed, closed universe of 10 stocks this app knows about, using their
/// real NSE trading symbols. Deliberately static (not fetched from a
/// network) so the whole app is deterministic and works fully offline.
class StockUniverse {
  StockUniverse._();

  static const List<Stock> all = <Stock>[
    Stock(symbol: 'RELIANCE', name: 'Reliance Industries', seedPrice: Money.fromPaise(284550)),
    Stock(symbol: 'TCS', name: 'Tata Consultancy Services', seedPrice: Money.fromPaise(384200)),
    Stock(symbol: 'INFY', name: 'Infosys', seedPrice: Money.fromPaise(148075)),
    Stock(symbol: 'HDFCBANK', name: 'HDFC Bank', seedPrice: Money.fromPaise(164325)),
    Stock(symbol: 'ICICIBANK', name: 'ICICI Bank', seedPrice: Money.fromPaise(122050)),
    Stock(symbol: 'SBIN', name: 'State Bank of India', seedPrice: Money.fromPaise(81475)),
    Stock(symbol: 'ITC', name: 'ITC Limited', seedPrice: Money.fromPaise(43620)),
    Stock(symbol: 'LT', name: 'Larsen & Toubro', seedPrice: Money.fromPaise(362900)),
    Stock(symbol: 'BHARTIARTL', name: 'Bharti Airtel', seedPrice: Money.fromPaise(156800)),
    Stock(symbol: 'AXISBANK', name: 'Axis Bank', seedPrice: Money.fromPaise(123000)),
  ];

  static Stock bySymbol(String symbol) =>
      all.firstWhere((Stock s) => s.symbol == symbol,
          orElse: () => throw ArgumentError('Unknown symbol: $symbol'));
}
