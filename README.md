# moinsen_runapp

[![pub package](https://img.shields.io/pub/v/moinsen_runapp.svg)](https://pub.dev/packages/moinsen_runapp)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

Drop-in `runApp()` replacement with three-layer error catching, deduplication, beautiful error screens, and a CLI tool for live LLM-assisted debugging.

## Why?

Flutter's default error handling lets errors slip through the cracks. An uncaught async error kills your app. A widget build error shows the infamous red screen of death. Init failures crash before users see anything.

`moinsen_runapp` catches **everything** and keeps your app running.

## Features

- **Three-layer error catching** — Flutter framework errors, platform dispatcher errors, and zone-level uncaught errors. Nothing escapes.
- **App always starts** — Init failures are caught and logged but never prevent launch.
- **Error deduplication** — Identical errors within a configurable time window are counted, not repeated. No "1000 identical errors in 3 seconds."
- **Beautiful release screens** — Three built-in variants (friendly, minimal, illustrated) with automatic dark/light mode support.
- **Rich debug screen** — Expandable error tiles with source badges, dedup counts, full stack traces, and a "Copy All" button that generates a structured markdown bug report.
- **Smart console logging** — Full output for the first few errors, then automatic burst compression to avoid flooding your console.
- **Optional file logging** — Write errors to disk with automatic 1 MB rotation.
- **External error reporting** — `onError` callback for forwarding to Sentry, Crashlytics, or any backend.
- **Custom screen builders** — Replace any built-in screen with your own widget.
- **Crash-proof error boundary** — Error screen renders as a sibling of your app (via `Stack`), so it works even if your entire widget tree fails to build.
- **CLI tool for LLM debugging** — `moinsen_run` wraps `flutter run` and exposes errors, logs, and app state as structured JSON. Query errors, trigger hot reload, or get an LLM-ready bug report — all from the terminal.
- **VM Service extensions** — Five `ext.moinsen.*` extensions registered in debug mode let tools like Claude Code query app state live via the Dart VM Service Protocol.
- **Zero configuration required** — Works out of the box with sensible defaults. One line to integrate.
- **All Flutter platforms** — iOS, Android, web, macOS, Windows, Linux.

## Installation

```yaml
dependencies:
  moinsen_runapp: ^0.3.0
```

Or run:

```bash
flutter pub add moinsen_runapp
```

## Quick Start

Replace your `runApp()` call:

```dart
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(child: const MyApp());
}
```

That's it. Your app now has three-layer error catching, deduplication, a debug error screen in development, and a friendly error screen in release mode.

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

# Check if the app is running
dart run moinsen_runapp:moinsen_run status
```

### Control the running app

```bash
# Trigger hot reload
dart run moinsen_runapp:moinsen_run reload

# Trigger hot restart
dart run moinsen_runapp:moinsen_run restart

# Dump the widget tree
dart run moinsen_runapp:moinsen_run state

# Stop the app
dart run moinsen_runapp:moinsen_run stop
```

### Static analysis

```bash
# Run flutter analyze with structured JSON output
dart run moinsen_runapp:moinsen_run analyze
```

### All commands

| Command | Description |
|---|---|
| *(default)* | Start `flutter run` with JSON line streaming |
| `errors` | Get deduplicated error report from running app |
| `prompt` | Get LLM-ready markdown bug report |
| `logs` | Get recent log entries (`--last N`, default 50) |
| `status` | Check if app is running, show device and uptime |
| `reload` | Trigger hot reload |
| `restart` | Trigger hot restart (resets app state) |
| `state` | Dump widget tree via `debugDumpApp()` |
| `analyze` | Run `flutter analyze` with structured output |
| `stop` | Stop the running app |

## VM Service Extensions

In debug and profile mode, `moinsenRunApp()` automatically registers five VM Service extensions:

| Extension | Returns |
|---|---|
| `ext.moinsen.getErrors` | `{errors: [...], totalCount, uniqueCount}` |
| `ext.moinsen.clearErrors` | `{cleared: true}` |
| `ext.moinsen.getInfo` | `{package, errorCount, uniqueErrors, platform}` |
| `ext.moinsen.getLogs` | `{logs: [...], capacity, size}` |
| `ext.moinsen.getPrompt` | `{prompt: "# Bug Report\n..."}` |

These extensions are what the CLI tool uses under the hood. Any tool that speaks the Dart VM Service Protocol can call them directly.

## Custom Error Screens

Override the built-in screens with your own. The builder receives the current `BuildContext` and the list of `ErrorEntry` objects:

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

The `onError` callback fires for every error (including duplicates within the dedup window), so your external service gets the full picture.

## How It Works

```
  CLI (moinsen_run)                    Flutter App (Debug)
  ┌──────────────────┐                ┌──────────────────────────────────┐
  │ moinsen_run       │──starts──────▶│ runZonedGuarded (layer 3)        │
  │ moinsen_run errors│               │  PlatformDispatcher.onError (2)  │
  │ moinsen_run reload│──VM Service──▶│  FlutterError.onError (1)        │
  │ moinsen_run prompt│               │  Your App (ErrorBoundaryWidget)  │
  │ moinsen_run logs  │               └──────────────┬───────────────────┘
  └────────┬─────────┘                               │
           │                                All errors funnel into:
  .moinsen_run.json                                  ▼
  (VM Service URI, PID)               ┌─────────────────────────┐
                                      │      ErrorBucket        │ ← dedup by hash
                                      └────────────┬────────────┘
                                                   │
                              ┌─────────────────────┼──────────────────────┐
                              ▼                     ▼                      ▼
                    ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
                    │  ErrorObserver   │  │    LogBuffer     │  │  VM Extensions   │
                    │ (ChangeNotifier) │  │ (ring buffer,    │  │ ext.moinsen.*    │
                    └────────┬─────────┘  │  capacity 200)   │  │ (5 endpoints)    │
                             │            └──────────────────┘  └──────────────────┘
                    ┌────────▼─────────┐
                    │  ErrorBoundary   │ ← Stack-based: error screen
                    │  Widget (Stack)  │   renders independently
                    └──────────────────┘
```

1. **Zone guard** wraps everything in `runZonedGuarded`. This is the outermost net — catches async errors that escape both Flutter and the platform dispatcher.
2. **Platform dispatcher** intercepts `PlatformDispatcher.onError` for dart:ui-level uncaught errors.
3. **Flutter error handler** intercepts `FlutterError.onError` for widget build, layout, and paint errors.
4. **Error bucket** deduplicates errors by hashing (runtime type + message + top 3 stack frames). Identical errors within the dedup window increment a counter instead of creating new entries.
5. **Error observer** is a `ChangeNotifier` that drives the UI. Notifications are deferred via `Timer.run()` to avoid triggering rebuilds during Flutter's build/layout/paint phase.
6. **Error boundary widget** wraps your app in a `Stack`. The error screen overlay is a *sibling* of your app widget — if your widget tree fails completely, the error screen still renders independently.

7. **Log buffer** is a fixed-capacity ring buffer (200 entries) that captures structured log entries for the `ext.moinsen.getLogs` extension.
8. **VM Service extensions** expose five `ext.moinsen.*` endpoints in debug/profile mode, allowing external tools to query errors, logs, and app metadata live via the Dart VM Service Protocol.

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
| `logToFile` | `false` | Write error summaries to a log file on disk |
| `logFilePath` | `null` | Explicit log file path (auto-resolved via `path_provider` if null) |
| `releaseScreenVariant` | `ErrorScreenVariant.friendly` | Built-in release error screen variant |
| `releaseScreenBuilder` | `null` | Custom release error screen — overrides `releaseScreenVariant` |
| `debugScreenBuilder` | `null` | Custom debug error screen — overrides the built-in debug overlay |

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

**Methods:**

| Method | Returns | Description |
|---|---|---|
| `toJson()` | `Map<String, dynamic>` | Serialize to JSON (used by VM extensions and CLI) |

### `moinsenReportError`

Manually report caught errors through the full pipeline (dedup, console log, file log, UI notification, external callback):

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  moinsenReportError(e, stack, source: 'api');
}
```

### `generateBugReport`

Generate a structured markdown bug report from error entries:

```dart
import 'package:moinsen_runapp/src/prompt_generator.dart';

final report = generateBugReport(
  errors: errorObserver.errors,
  platform: defaultTargetPlatform.name,
);
```

This is the same function used by the debug screen's "Copy All" button and the `ext.moinsen.getPrompt` VM extension.

## License

MIT License. See [LICENSE](LICENSE) for details.
