import '../../../core/stock.dart';

class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.symbols,
  });

  final String id;
  final String name;
  final List<String> symbols;

  List<Stock> get stocks => symbols
      .where((String symbol) => StockUniverse.all.any((Stock s) => s.symbol == symbol))
      .map((String symbol) => StockUniverse.bySymbol(symbol))
      .toList(growable: false);

  Watchlist copyWith({String? id, String? name, List<String>? symbols}) {
    return Watchlist(
      id: id ?? this.id,
      name: name ?? this.name,
      symbols: symbols ?? List<String>.of(this.symbols),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'symbols': List<String>.of(symbols),
      };

  factory Watchlist.fromMap(Map<dynamic, dynamic> map) {
    return Watchlist(
      id: map['id'] as String,
      name: map['name'] as String,
      symbols: (map['symbols'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic value) => value.toString())
          .toList(growable: false),
    );
  }
}
