# moinsen_runapp

[![pub package](https://img.shields.io/pub/v/moinsen_runapp.svg)](https://pub.dev/packages/moinsen_runapp)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The universal LLM debug bridge for Flutter. Drop-in `runApp()` replacement with three-layer error catching, app-level logging, navigation tracking, screenshot capture, and a CLI tool for live LLM-assisted debugging.

## Why?

Flutter's default error handling lets errors slip through the cracks. An uncaught async error kills your app. A widget build error shows the infamous red screen of death. Init failures crash before users see anything.

`moinsen_runapp` catches **everything**, keeps your app running, and gives LLM tools like Claude Code full visibility into your app's state.

## Features

- **Three-layer error catching** — Flutter framework errors, platform dispatcher errors, and zone-level uncaught errors. Nothing escapes.
- **App always starts** — Init failures are caught and logged but never prevent launch.
- **Error deduplication** — Identical errors within a configurable time window are counted, not repeated.
- **Beautiful release screens** — Three built-in variants (friendly, minimal, illustrated) with automatic dark/light mode support.
- **Rich debug screen** — Expandable error tiles with source badges, dedup counts, full stack traces, and a "Copy All" button.
- **App-level logging** — `moinsenLog()` surfaces navigation events, API calls, and state changes to external tooling.
- **Navigation tracking** — `MoinsenNavigatorObserver` tracks route changes, exposes history, and enables programmatic navigation.
- **Screenshot capture** — Capture the current screen as PNG via VM Service or CLI. No `RepaintBoundary` needed.
- **LLM context command** — `moinsen_run context` aggregates errors, logs, routes, screenshots, and widget tree into one markdown document.
- **CLI tool** — `moinsen_run` wraps `flutter run` and exposes 16 commands for querying and controlling your app.
- **9 VM Service extensions** — `ext.moinsen.*` endpoints let any tool query app state live via the Dart VM Service Protocol.
- **Smart console logging** — Full output for the first few errors, then automatic burst compression.
- **Optional file logging** — Write errors to disk with automatic 1 MB rotation.
- **External error reporting** — `onError` callback for forwarding to Sentry, Crashlytics, or any backend.
- **Zero configuration required** — Works out of the box with sensible defaults. One line to integrate.
- **All Flutter platforms** — iOS, Android, web, macOS, Windows, Linux.

## Installation

```yaml
dependencies:
  moinsen_runapp: ^1.0.0
```

Or run:

```bash
flutter pub add moinsen_runapp
```

## Quick Start

### 1. Replace `runApp()`

```dart
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(child: const MyApp());
}
```

### 2. Add the navigator observer

```dart
MaterialApp(
  navigatorObservers: [MoinsenNavigatorObserver.instance],
  // ...
)
```

### 3. Log from your app

```dart
moinsenLog('User tapped checkout', source: 'cart', level: 'info');
moinsenLog('API returned 500', source: 'api', level: 'error');
```

That's it. Your app now has error catching, log capture, route tracking, and full LLM debugging support.

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

If `init` throws, the error is caught, logged, and displayed — but `MyApp()` still runs.

## Configuration

```dart
void main() {
  moinsenRunApp(
    config: const RunAppConfig(
      releaseScreenVariant: ErrorScreenVariant.minimal,
      logToFile: true,
      logBufferCapacity: 500,          // default: 200
      screenshotMaxDimension: 1080,    // cap screenshot resolution
    ),
    onError: (error, stackTrace) {
      Sentry.captureException(error, stackTrace: stackTrace);
    },
    child: const MyApp(),
  );
}
```

## Release Screen Variants

All variants automatically adapt to dark and light mode.

| Variant | Description |
|---|---|
| `ErrorScreenVariant.friendly` | Wobbling animated character with purple tones and an "Oops!" message. Warm and approachable. |
| `ErrorScreenVariant.minimal` | Clean screen with an error icon, "Something went wrong" message, and a retry button. No animation. |
| `ErrorScreenVariant.illustrated` | Full-screen CustomPainter with a floating broken-link motif, bobbing animation, and decorative dots. |

## Debug Screen

In debug mode, errors are shown in a dark developer-focused overlay with:

- **Error tiles** — Each unique error as an expandable card showing runtime type, message, source badge (`flutter` / `platform` / `zone` / `init`), and dedup count.
- **Full stack traces** — Tap to expand any error and see the complete stack trace.
- **Copy All** — Generates a structured markdown bug report with Flutter diagnostics, app-filtered stack traces, and framework context traces. Paste directly into a GitHub issue.
- **Dismiss** — Hide the overlay and continue using the app. Errors stop being captured while dismissed to avoid noise.
- **Clear & Retry** — Reset all tracked errors and resume error capture.
- **Kill App** — Force-quit for when you need a clean restart.

## CLI Tool: `moinsen_run`

The `moinsen_run` CLI wraps `flutter run` and connects to your running app via the Dart VM Service Protocol. All output is structured JSON, making it ideal for LLM tools like Claude Code.

### Start the app

```bash
dart run moinsen_runapp:moinsen_run
```

This starts `flutter run`, captures the VM Service URI, and streams structured JSON lines (logs, errors, lifecycle events) to stdout. A state file (`.moinsen_run.json`) is written to the project root for subsequent commands.

### Query the running app

```bash
# Get all deduplicated errors as JSON
dart run moinsen_runapp:moinsen_run errors

# Get an LLM-ready markdown bug report
dart run moinsen_runapp:moinsen_run prompt

# Get recent log entries (default: last 50)
dart run moinsen_runapp:moinsen_run logs --last 20

# Get current route and navigation history
dart run moinsen_runapp:moinsen_run route

# Capture a screenshot (saved as PNG)
dart run moinsen_runapp:moinsen_run screenshot

# Get full LLM-ready context (errors + logs + route + optional screenshot)
dart run moinsen_runapp:moinsen_run context --with-screenshot --with-tree
```

### Control the running app

```bash
# Trigger hot reload
dart run moinsen_runapp:moinsen_run reload

# Trigger hot restart
dart run moinsen_runapp:moinsen_run restart

# Push a named route
dart run moinsen_runapp:moinsen_run navigate --push /settings

# Pop the current route
dart run moinsen_runapp:moinsen_run navigate --pop

# Dump the widget tree
dart run moinsen_runapp:moinsen_run state

# Stop the app
dart run moinsen_runapp:moinsen_run stop
```

### All CLI commands

| Command | Description |
|---|---|
| *(default)* | Start `flutter run` with JSON line streaming |
| `errors` | Get deduplicated error report from running app |
| `prompt` | Get LLM-ready markdown bug report |
| `logs` | Get recent log entries (`--last N`, default 50) |
| `route` | Get current route and navigation history |
| `screenshot` | Capture screen as PNG |
| `navigate` | Push a named route (`--push`) or pop (`--pop`) |
| `context` | Full LLM-ready context (`--with-screenshot`, `--with-tree`, `--log-count`, `--format`) |
| `status` | Check if app is running, show device and uptime |
| `reload` | Trigger hot reload |
| `restart` | Trigger hot restart (resets app state) |
| `state` | Dump widget tree via `debugDumpApp()` |
| `analyze` | Run `flutter analyze` with structured output |
| `stop` | Stop the running app |

## VM Service Extensions

In debug and profile mode, `moinsenRunApp()` automatically registers nine VM Service extensions:

| Extension | Returns |
|---|---|
| `ext.moinsen.getErrors` | `{errors: [...], totalCount, uniqueCount}` |
| `ext.moinsen.clearErrors` | `{cleared: true}` |
| `ext.moinsen.getInfo` | `{package, errorCount, uniqueErrors, platform}` |
| `ext.moinsen.getLogs` | `{logs: [...], capacity, size}` |
| `ext.moinsen.getPrompt` | `{prompt: "# Enhanced Bug Report\n..."}` |
| `ext.moinsen.screenshot` | `{png: "<base64>", width, height}` |
| `ext.moinsen.getRoute` | `{currentRoute, observerInstalled, history: [...]}` |
| `ext.moinsen.navigate` | `{success: true}` (params: `action`, `route`) |
| `ext.moinsen.getContext` | `{context: "# App Context Report\n..."}` |

These extensions are what the CLI tool uses under the hood. Any tool that speaks the Dart VM Service Protocol can call them directly.

## App-Level Logging

Use `moinsenLog()` to surface app events to external tooling:

```dart
// Log with level and source for filtering
moinsenLog('Payment completed', source: 'checkout', level: 'info');
moinsenLog('Token refresh failed', source: 'auth', level: 'error');

// Simple debug logging
moinsenLog('Widget rebuilt with new state');
```

Logs are stored in a ring buffer (default capacity: 200) and served via `ext.moinsen.getLogs` and the `moinsen_run logs` CLI command. They are also included in `prompt` and `context` output.

## Navigation Tracking

Add `MoinsenNavigatorObserver.instance` to your app's navigator:

```dart
MaterialApp(
  navigatorObservers: [MoinsenNavigatorObserver.instance],
  home: const HomePage(),
)
```

This enables:
- `moinsen_run route` — view current route and navigation history
- `moinsen_run navigate --push /settings` — push routes programmatically
- `moinsen_run navigate --pop` — pop the current route
- Route info in `prompt` and `context` output

## Custom Error Screens

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
  },
  child: const MyApp(),
);
```

## How It Works

```
  CLI (moinsen_run)                    Flutter App (Debug)
  ┌──────────────────┐                ┌──────────────────────────────────┐
  │ moinsen_run       │──starts──────▶│ runZonedGuarded (layer 3)        │
  │ moinsen_run errors│               │  PlatformDispatcher.onError (2)  │
  │ moinsen_run prompt│──VM Service──▶│  FlutterError.onError (1)        │
  │ moinsen_run logs  │               │  Your App (ErrorBoundaryWidget)  │
  │ moinsen_run route │               │  MoinsenNavigatorObserver        │
  │ moinsen_run screensht             │  moinsenLog() → LogBuffer        │
  │ moinsen_run context│              └──────────────┬───────────────────┘
  └────────┬─────────┘                               │
           │                                All errors funnel into:
  .moinsen_run.json                                  ▼
  (VM Service URI, PID)               ┌─────────────────────────┐
                                      │      ErrorBucket        │ ← dedup by hash
                                      └────────────┬────────────┘
                                                   │
                      ┌────────────────┬───────────┼──────────────────────┐
                      ▼                ▼           ▼                      ▼
            ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
            │  ErrorObserver   │  │    LogBuffer     │  │  VM Extensions   │
            │ (ChangeNotifier) │  │ (ring buffer,    │  │ ext.moinsen.*    │
            └────────┬─────────┘  │  capacity 200)   │  │ (9 endpoints)    │
                     │            └──────────────────┘  └──────────────────┘
            ┌────────▼─────────┐         ▲
            │  ErrorBoundary   │         │
            │  Widget (Stack)  │   ScreenshotService
            └──────────────────┘   NavigatorObserver
```

1. **Zone guard** wraps everything in `runZonedGuarded`. This is the outermost net — catches async errors that escape both Flutter and the platform dispatcher.
2. **Platform dispatcher** intercepts `PlatformDispatcher.onError` for dart:ui-level uncaught errors.
3. **Flutter error handler** intercepts `FlutterError.onError` for widget build, layout, and paint errors.
4. **Error bucket** deduplicates errors by hashing (runtime type + message + top 3 stack frames). Identical errors within the dedup window increment a counter instead of creating new entries.
5. **Error observer** is a `ChangeNotifier` that drives the UI. Notifications are deferred via `Timer.run()` to avoid triggering rebuilds during Flutter's build/layout/paint phase.
6. **Error boundary widget** wraps your app in a `Stack`. The error screen overlay is a *sibling* of your app widget — if your widget tree fails completely, the error screen still renders independently.
7. **Log buffer** is a fixed-capacity ring buffer that captures structured log entries from `moinsenLog()` calls.
8. **Navigator observer** tracks route changes and enables programmatic navigation via VM Service extensions.
9. **Screenshot service** captures the current screen directly from the render view's layer tree.
10. **VM Service extensions** expose nine `ext.moinsen.*` endpoints in debug/profile mode, allowing external tools to query errors, logs, routes, screenshots, and aggregated context live via the Dart VM Service Protocol.

When the error screen is displayed, error capture is automatically **paused** to avoid counting cascading duplicates. It resumes when the user taps "Dismiss" or "Clear & Retry."

## API Reference

### `moinsenRunApp`

| Parameter | Type | Description |
|---|---|---|
| `child` | `Widget` | Your app widget (required) |
| `init` | `Future<void> Function()?` | Async initialization — errors caught but never prevent launch |
| `onError` | `void Function(Object, StackTrace)?` | Callback for external error reporting |
| `config` | `RunAppConfig` | Configuration (all optional, sensible defaults) |

### `RunAppConfig`

| Parameter | Default | Description |
|---|---|---|
| `deduplicationWindow` | `Duration(seconds: 2)` | Time window for deduplicating identical errors |
| `maxLoggedErrors` | `50` | Maximum unique errors to track before evicting oldest |
| `logBufferCapacity` | `200` | Maximum entries the app-level log buffer retains |
| `logToFile` | `false` | Write error summaries to a log file on disk |
| `logFilePath` | `null` | Explicit log file path (auto-resolved via `path_provider` if null) |
| `screenshotMaxDimension` | `null` | Cap screenshot resolution in physical pixels |
| `releaseScreenVariant` | `ErrorScreenVariant.friendly` | Built-in release error screen variant |
| `releaseScreenBuilder` | `null` | Custom release error screen — overrides `releaseScreenVariant` |
| `debugScreenBuilder` | `null` | Custom debug error screen — overrides the built-in debug overlay |

### `moinsenLog`

```dart
void moinsenLog(String message, {String? source, String level = 'info'})
```

Log a message to the shared log buffer. Messages appear in `ext.moinsen.getLogs`, `moinsen_run logs`, and are included in prompt/context output.

### `MoinsenNavigatorObserver`

| Property / Method | Description |
|---|---|
| `MoinsenNavigatorObserver.instance` | Shared singleton instance |
| `currentRoute` | Current route name (or `null`) |
| `history` | Unmodifiable list of `RouteRecord` entries |
| `pushNamed(route)` | Push a named route via the observer's navigator |
| `pop()` | Pop the current route |

### `RouteRecord`

| Property | Type | Description |
|---|---|---|
| `action` | `String` | `'push'`, `'pop'`, `'replace'`, or `'remove'` |
| `routeName` | `String?` | Route name from `RouteSettings.name` |
| `arguments` | `String?` | String representation of route arguments |
| `timestamp` | `DateTime` | When this navigation occurred |

### `ErrorEntry`

Each error tracked by the system is represented as an `ErrorEntry`. Custom screen builders receive `List<ErrorEntry>`.

| Property | Type | Description |
|---|---|---|
| `hash` | `String` | Unique hash (error type + message + top stack frames) |
| `error` | `Object` | The original error object |
| `stackTrace` | `StackTrace` | Stack trace captured at the error site |
| `source` | `String` | Where the error was caught: `'flutter'`, `'platform'`, `'zone'`, or `'init'` |
| `diagnostics` | `String?` | Rich Flutter diagnostic context (for framework errors) |
| `firstSeen` | `DateTime` | When this error was first seen |
| `lastSeen` | `DateTime` | When this error was last seen (updated on duplicates) |
| `count` | `int` | How many times this exact error has occurred |
| `label` | `String` | Short human-readable label (truncated to 120 chars) |
| `span` | `Duration` | Duration between first and last occurrence |

### `moinsenReportError`

Manually report caught errors through the full pipeline:

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  moinsenReportError(e, stack, source: 'api');
}
```

### `ScreenshotService`

| Method | Description |
|---|---|
| `ScreenshotService.capture({pixelRatio, maxDimension})` | Capture current screen as PNG. Returns `ScreenshotResult?` |

### `ScreenshotResult`

| Property | Type | Description |
|---|---|---|
| `bytes` | `Uint8List` | PNG image bytes |
| `width` | `int` | Image width in physical pixels |
| `height` | `int` | Image height in physical pixels |

## License

MIT License. See [LICENSE](LICENSE) for details.
