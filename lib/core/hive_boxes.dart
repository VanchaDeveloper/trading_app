/// Names every Hive box used by the app in one place, so a typo in a box
/// name can never silently create a second, orphaned box.
class HiveBoxes {
  HiveBoxes._();

  /// Single-entry box holding the wallet balance (key: 'balance_paise').
  static const String wallet = 'box_wallet';

  /// List box of executed orders (each entry is a `Map<String, dynamic>`).
  static const String orders = 'box_orders';

  /// Single-entry box holding the ordered list of watchlist symbols
  /// (key: 'symbols').
  static const String watchlist = 'box_watchlist';

  /// Box containing the full watched-list catalog in named watchlist form.
  /// Each key is a watchlist id and each value is a map containing its
  /// name and ordered symbols.
  static const String watchlists = 'box_watchlists';
}
