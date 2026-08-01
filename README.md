# Trading App

A Flutter-based trading dashboard with a dark theme and three main screens:

- Watchlist
- Live Prices
- Holdings

The app is organized around a bottom navigation shell and uses `flutter_bloc` for state management, with local persistence handled through Hive.

## Features

- Browse a watchlist of tracked stocks
- View live price updates in a dedicated prices screen
- Manage holdings and portfolio information
- Buy/sell trading flow accessed from stock rows
- Dark theme UI optimized for market monitoring

## Project Structure

- `lib/main.dart` – app bootstrap and root navigation shell
- `lib/features/` – feature modules for watchlist, live prices, and holdings
- `lib/core/` – shared utilities, theme, money, stock, and async helpers
- `lib/di/` – dependency injection setup

## Getting Started

### Prerequisites

- Flutter SDK (version compatible with the project)
- Dart SDK
- A supported IDE such as VS Code or Android Studio

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

## Notes

This project uses:

- Flutter
- Dart
- Hive
- flutter_bloc

If you are starting from a clean clone, make sure to run `flutter pub get` before launching the app.

## License

This project is for educational/demo purposes unless otherwise stated.
