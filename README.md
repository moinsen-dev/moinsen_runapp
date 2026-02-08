# moinsen_runapp

[![pub package](https://img.shields.io/pub/v/moinsen_runapp.svg)](https://pub.dev/packages/moinsen_runapp)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Drop-in `runApp()` replacement with three-layer error catching, deduplication, and beautiful error screens for Flutter.

## Why?

Flutter's default error handling lets errors slip through the cracks. `moinsen_runapp` catches **everything** across three layers — Flutter framework errors, platform dispatcher errors, and uncaught zone errors — deduplicates them, and shows your users a polished error screen instead of a red wall of text.

**Your app always starts.** Init failures are caught and logged but never prevent launch.

## Installation

```yaml
dependencies:
  moinsen_runapp: ^0.1.0
```

## Quick Start

Replace your `runApp()` call:

```dart
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(child: const MyApp());
}
```

## With Initialization

Run async setup that might fail — the app still launches:

```dart
void main() {
  moinsenRunApp(
    init: () async {
      await Firebase.initializeApp();
      await Hive.initFlutter();
    },
    child: const MyApp(),
  );
}
```

## Configuration

```dart
void main() {
  moinsenRunApp(
    config: const RunAppConfig(
      // Deduplicate identical errors within this window
      deduplicationWindow: Duration(seconds: 2),
      // Max unique errors to track
      maxLoggedErrors: 50,
      // Write errors to a log file
      logToFile: true,
      // Choose a release screen variant
      releaseScreenVariant: ErrorScreenVariant.friendly,
    ),
    child: const MyApp(),
  );
}
```

### Release Screen Variants

| Variant | Description |
|---|---|
| `ErrorScreenVariant.friendly` | Animated character with warm colors and "Oops!" message |
| `ErrorScreenVariant.minimal` | Clean screen with icon, message, and retry button |
| `ErrorScreenVariant.illustrated` | Full-screen CustomPainter illustration with animation |

### Custom Error Screens

Override the built-in screens with your own:

```dart
moinsenRunApp(
  config: RunAppConfig(
    releaseScreenBuilder: (context, errors) {
      return YourCustomErrorScreen(errors: errors);
    },
    debugScreenBuilder: (context, errors) {
      return YourDebugErrorScreen(errors: errors);
    },
  ),
  child: const MyApp(),
);
```

## External Error Reporting

Forward errors to Sentry, Crashlytics, or any other service:

```dart
moinsenRunApp(
  onError: (error, stackTrace) {
    Sentry.captureException(error, stackTrace: stackTrace);
    // or: FirebaseCrashlytics.instance.recordError(error, stackTrace);
  },
  child: const MyApp(),
);
```

## How It Works

1. **Zone guard** — wraps everything in `runZonedGuarded` to catch async errors
2. **Flutter error handler** — intercepts `FlutterError.onError` for widget build/layout/paint errors
3. **Platform dispatcher** — catches dart:ui-level uncaught errors
4. **Error bucket** — deduplicates by error hash (type + message + top stack frames)
5. **Error observer** — `ChangeNotifier` that drives the UI, with deferred notifications to avoid build-phase conflicts
6. **Error boundary widget** — wraps your app tree and shows the error screen overlay

## API Reference

### `moinsenRunApp`

| Parameter | Type | Description |
|---|---|---|
| `child` | `Widget` | Your app widget (required) |
| `init` | `Future<void> Function()?` | Async initialization callback |
| `onError` | `void Function(Object, StackTrace)?` | External error reporting callback |
| `config` | `RunAppConfig` | Configuration options |

### `RunAppConfig`

| Parameter | Default | Description |
|---|---|---|
| `deduplicationWindow` | `Duration(seconds: 2)` | Time window for deduplicating identical errors |
| `maxLoggedErrors` | `50` | Maximum unique errors to track |
| `logToFile` | `false` | Write error summaries to a log file |
| `logFilePath` | `null` | Explicit log file path (auto-resolved if null) |
| `releaseScreenVariant` | `ErrorScreenVariant.friendly` | Built-in release screen variant |
| `releaseScreenBuilder` | `null` | Custom release error screen builder |
| `debugScreenBuilder` | `null` | Custom debug error screen builder |

### `ErrorObserver`

A `ChangeNotifier` exposed for advanced use cases:

- `hasErrors` — whether any errors have been recorded
- `totalErrorCount` — total error occurrences
- `uniqueErrorCount` — number of unique errors
- `errors` — current list of `ErrorEntry` objects
- `pause()` / `resume()` — control error capture
- `clearErrors()` — reset all tracked errors

## License

MIT License. See [LICENSE](LICENSE) for details.
