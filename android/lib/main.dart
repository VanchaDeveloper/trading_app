import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'di/service_locator.dart';
import 'features/holdings/presentation/holdings_page.dart';
import 'features/live_prices/presentation/live_prices_page.dart';
import 'features/watchlist/presentation/watchlist_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServiceLocator.instance.init();
  runApp(const TradingApp());
}

class TradingApp extends StatelessWidget {
  const TradingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trading App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const RootShell(),
    );
  }
}

/// Bottom-nav shell hosting all three primary tabs. Watchlist, Live Prices,
/// and Holdings are the tabs; Buy/Sell Ticket is reached by tapping any
/// stock row from either Watchlist or Live Prices, so it deliberately has
/// no tab of its own.
///
/// Uses an [IndexedStack] rather than swapping widgets on tab change, so
/// each tab's state (e.g. the Holdings tab's `HoldingsCubit` and its
/// throttled price-refresh timer) is created once and kept alive across
/// tab switches instead of being torn down and rebuilt every time.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<Widget> _tabs = <Widget>[
    WatchlistPage(),
    LivePricesPage(),
    HoldingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.star_outline), selectedIcon: Icon(Icons.star), label: 'Watchlist'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Live Prices'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), selectedIcon: Icon(Icons.pie_chart), label: 'Holdings'),
        ],
      ),
    );
  }
}
