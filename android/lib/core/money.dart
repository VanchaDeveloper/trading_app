/// A currency value represented as an integer number of paise (1 rupee = 100
/// paise). We NEVER use `double` for money: doubles cannot represent
/// currency exactly (0.1 + 0.2 != 0.3), which silently corrupts wallet
/// balances and P&L over many operations. All arithmetic here is integer
/// arithmetic, so it is exact by construction.
class Money implements Comparable<Money> {
  const Money.fromPaise(this.paise);

  /// Convenience constructor from a whole-rupee integer amount.
  const Money.fromRupees(int rupees) : paise = rupees * 100;

  /// Parses a decimal rupee string (e.g. "1234.56") into exact paise.
  /// Throws [FormatException] if the string isn't a valid amount with at
  /// most 2 decimal places.
  factory Money.parse(String input) {
    final String trimmed = input.trim();
    final RegExp pattern = RegExp(r'^-?\d+(\.\d{1,2})?$');
    if (!pattern.hasMatch(trimmed)) {
      throw FormatException('Not a valid money amount: "$input"');
    }
    final bool negative = trimmed.startsWith('-');
    final String unsigned = negative ? trimmed.substring(1) : trimmed;
    final List<String> parts = unsigned.split('.');
    final int rupeesPart = int.parse(parts[0]);
    final int paisePart = parts.length > 1
        ? int.parse(parts[1].padRight(2, '0'))
        : 0;
    final int total = rupeesPart * 100 + paisePart;
    return Money.fromPaise(negative ? -total : total);
  }

  static const Money zero = Money.fromPaise(0);

  /// Total value in paise. This is the single source of truth; rupees are
  /// always derived from this.
  final int paise;

  int get rupeesWhole => paise ~/ 100;
  int get paiseRemainder => paise.remainder(100).abs();

  bool get isNegative => paise < 0;
  bool get isZero => paise == 0;
  bool get isPositive => paise > 0;

  Money operator +(Money other) => Money.fromPaise(paise + other.paise);
  Money operator -(Money other) => Money.fromPaise(paise - other.paise);
  Money operator -() => Money.fromPaise(-paise);

  /// Multiplies by an integer quantity (e.g. price * shares). Multiplying
  /// money by money makes no financial sense, so only int multipliers are
  /// allowed.
  Money operator *(int quantity) => Money.fromPaise(paise * quantity);

  bool operator <(Money other) => paise < other.paise;
  bool operator <=(Money other) => paise <= other.paise;
  bool operator >(Money other) => paise > other.paise;
  bool operator >=(Money other) => paise >= other.paise;

  @override
  int compareTo(Money other) => paise.compareTo(other.paise);

  @override
  bool operator ==(Object other) => other is Money && other.paise == paise;

  @override
  int get hashCode => paise.hashCode;

  /// Formats as "₹1,234.56" (or "-₹1,234.56" for negative amounts).
  String format({bool withSymbol = true}) {
    final int absPaise = paise.abs();
    final int rupees = absPaise ~/ 100;
    final int fraction = absPaise % 100;
    final String rupeesGrouped = _groupIndian(rupees);
    final String sign = paise < 0 ? '-' : '';
    final String symbol = withSymbol ? '\u20B9' : '';
    final String fractionStr = fraction.toString().padLeft(2, '0');
    return '$sign$symbol$rupeesGrouped.$fractionStr';
  }

  /// Indian-style digit grouping: last 3 digits, then groups of 2.
  /// e.g. 1234567 -> "12,34,567"
  static String _groupIndian(int value) {
    final String digits = value.toString();
    if (digits.length <= 3) return digits;
    final String last3 = digits.substring(digits.length - 3);
    String rest = digits.substring(0, digits.length - 3);
    final List<String> groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    return '${groups.join(',')},$last3';
  }

  @override
  String toString() => format();
}
