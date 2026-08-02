/// One user-created watchlist: a name plus an ordered list of symbols.
/// Order in [symbols] IS display order, so reordering rows is just
/// "persist this list in its new order" — no separate `position` field to
/// keep in sync.
class Watchlist {
  const Watchlist({
    required this.id,
    required this.name,
    required this.symbols,
  });

  /// Stable identity, independent of [name] — this is what lets a
  /// watchlist be renamed without losing its place in storage, its
  /// navigation route, or its identity relative to other watchlists.
  final String id;

  final String name;
  final List<String> symbols;

  Watchlist copyWith({String? name, List<String>? symbols}) {
    return Watchlist(
      id: id,
      name: name ?? this.name,
      symbols: symbols ?? this.symbols,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'name': name,
        'symbols': symbols,
      };

  factory Watchlist.fromMap(Map<dynamic, dynamic> map) {
    return Watchlist(
      id: map['id'] as String,
      name: map['name'] as String,
      symbols: (map['symbols'] as List<dynamic>).cast<String>(),
    );
  }
}
