# Trading App

A Flutter trading dashboard for a simulated stock market workflow.

## Walkthrough Video

Add your Loom or unlisted YouTube link here before submission so reviewers can open the project and immediately view the feature walkthrough.

## Architecture Summary

The app is organized as a small feature-first Flutter application with a shared price feed boundary:

- `lib/main.dart` starts the app and hosts the bottom navigation shell.
- `lib/features/watchlist/` manages the user-selected watchlist and reorder flow.
- `lib/features/live_prices/` renders the full stock universe using live price tickers.
- `lib/features/holdings/` derives portfolio state from executed orders and refreshes price-only values on a throttle.
- `lib/data/market/` contains the `MarketDataService` interface and the offline mock tick engine.
- `lib/core/` contains shared domain types such as `Money`, `Stock`, `Theme`, and the Hive box constants.

## Design Decisions & Trade-offs

- `Money` is stored as integer paise rather than `double` to avoid floating-point drift.
- `Hive` is used for persistence instead of a SQL store to keep the app lightweight and fast to run with a minimal setup.
- Holdings are derived from the order history rather than storing a second copy of portfolio state, which keeps the source of truth simpler.
- The live price engine is throttled and routed through per-symbol `ValueListenable`s so only affected rows rebuild.

## Known Limitations

- The app uses a mock market feed rather than a real websocket or REST stream.
- Sector or chart analytics are intentionally not implemented in this version.
- The weighted-average cost calculation truncates on integer paise division, which is consistent with the current implementation but would need a more explicit precision policy for production-grade accounting.
- There is no real network reconnect or stale-feed handling because the brief is scoped to an offline market simulation.

## Features

- Reorderable watchlist with stock selection and edit flows
- Live price rows with per-symbol tick updates
- Holdings screen that derives current value, invested amount, and P&L from orders
- Buy/sell ticket flow with validation and execution confirmation

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK
- Android/iOS emulator or a connected device

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

### Run tests

```bash
flutter test
```

## License

This project is for educational/demo purposes unless otherwise stated.
