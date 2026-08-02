import 'package:flutter/material.dart';

/// Single source of truth for gain/loss/neutral colors. Every widget that
/// shows price change, P&L, or day-change must pull colors from here so the
/// app can never show inconsistent green/red semantics across features.
class MarketColors {
  MarketColors._();

  static const Color gain = Color(0xFF17C671);
  static const Color loss = Color(0xFFEF4444);
  static const Color neutral = Color(0xFF9AA1AC);

  static Color forChange(int changeSign) {
    if (changeSign > 0) return gain;
    if (changeSign < 0) return loss;
    return neutral;
  }
}

/// App-wide dark theme.
class AppTheme {
  AppTheme._();

  static const Color _background = Color(0xFF0E1116);
  static const Color _surface = Color(0xFF171B22);
  static const Color _surfaceAlt = Color(0xFF1F242D);
  static const Color _primary = Color(0xFF4C8DFF);
  static const Color _onSurfaceMuted = Color(0xFF8B93A1);

  static ThemeData get dark {
    final ColorScheme scheme = const ColorScheme.dark().copyWith(
      primary: _primary,
      surface: _surface,
      onSurface: Colors.white,
      surfaceContainerHighest: _surfaceAlt,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF262C36),
        thickness: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: _onSurfaceMuted),
      ),
    );
  }

  /// Tabular (monospaced-digit) style so price/quantity columns align as
  /// numbers tick — prevents the classic "jittering digits" bug when using
  /// a proportional font for live-updating numbers.
  static const TextStyle tabularFigures = TextStyle(
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    fontWeight: FontWeight.w600,
    fontSize: 15,
  );

  static const TextStyle tabularFiguresLarge = TextStyle(
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    fontWeight: FontWeight.w700,
    fontSize: 22,
  );
}
