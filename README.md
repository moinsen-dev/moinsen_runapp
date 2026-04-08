# moinsen_runapp

[![pub package](https://img.shields.io/pub/v/moinsen_runapp.svg)](https://pub.dev/packages/moinsen_runapp)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)

The universal LLM debug bridge for Flutter. Drop-in `runApp()` replacement with three-layer error catching, app-level logging, navigation tracking, screenshot capture, device context, lifecycle tracking, HTTP monitoring, state inspection, remote UI interaction (tap, scroll, text input), and an MCP server for AI agent integration.

## Why?

Flutter's default error handling lets errors slip through the cracks. An uncaught async error kills your app. A widget build error shows the infamous red screen of death. Init failures crash before users see anything.

`moinsen_runapp` catches **everything**, keeps your app running, and gives LLM tools like Claude Code full visibility into your app's state — not just *what* went wrong, but *why*.

## Features

### Error Handling
- **Three-layer error catching** — Flutter framework errors, platform dispatcher errors, and zone-level uncaught errors. Nothing escapes.
- **App always starts** — Init failures are caught and logged but never prevent launch.
- **Error deduplication** — Identical errors within a configurable time window are counted, not repeated.
- **Beautiful release screens** — Three built-in variants (friendly, minimal, illustrated) with automatic dark/light mode support.
- **Rich debug screen** — Expandable error tiles with source badges, dedup counts, full stack traces, and a "Copy All" button.
- **Smart console logging** — Full output for the first few errors, then automatic burst compression.
- **Optional file logging** — Write errors to disk with automatic 1 MB rotation.
- **External error reporting** — `onError` callback for forwarding to Sentry, Crashlytics, or any backend.

### LLM Context (Agentic Ready)
- **App-level logging** — `moinsenLog()` surfaces navigation events, API calls, and state changes to external tooling.
- **Navigation tracking** — `MoinsenNavigatorObserver` tracks route changes, exposes history, and enables programmatic navigation.
- **Screenshot capture** — Capture the current screen as PNG via VM Service or CLI. No `RepaintBoundary` needed.
- **Device & environment info** — Screen dimensions, pixel ratio, locale, brightness, text scale factor, accessibility features, OS version.
- **App lifecycle tracking** — Automatic `AppLifecycleState` transition recording with timestamps. Know when the app went to background.
- **HTTP/network monitoring** — Zero-config interception of all `dart:io` HTTP traffic. Records method, URL, status, duration, and sanitized headers.
- **State inspection** — Opt-in API for exposing app state (Bloc, Riverpod, Provider — anything) to LLM tools via lazy snapshot functions.
- **LLM context command** — `moinsen_run context` aggregates everything into one structured markdown document optimized for LLM consumption.

### Remote UI Interaction (opt-in)
- **Interactive element discovery** — See all tappable widgets on screen with type, key, text, bounds, and visibility.
- **Tap, scroll, enter text** — Remote-control the app by key, text content, widget type, or screen coordinates.
- **Widget matching** — 4 strategies with configurable callbacks for custom widgets.
- **Hit-test validation** — Only reports elements that can actually receive pointer events.

### Tooling
- **CLI tool** — `moinsen_run` wraps `flutter run` and exposes 24 commands for querying and controlling your app.
- **MCP server** — `moinsen_mcp` exposes all capabilities as 21 MCP tools for AI agents (Claude Code, Cursor, etc.).
- **17 VM Service extensions** — `ext.moinsen.*` endpoints let any tool query and control app state live.
- **Zero configuration required** — Works out of the box with sensible defaults. One line to integrate.

## Installation

```yaml
dependencies:
  moinsen_runapp: ^0.6.0
```

Or run:

```bash
flutter pub add moinsen_runapp
```

### AI Agent Skills

This package includes AI agent skills that teach tools like Claude Code and Cursor how to use moinsen_runapp. Install them with the [`skills`](https://pub.dev/packages/skills) CLI:

```bash
dart pub global activate skills
skills get
```

This copies the skill definitions from the package into your IDE's skills directory.

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

### 4. Expose state for LLM debugging (optional)

```dart
moinsenExposeState('cart', () => cartBloc.state.toJson());
moinsenExposeState('user', () => userRepo.currentUser?.toJson());
```

That's it. Your app now has error catching, log capture, route tracking, device context, lifecycle tracking, HTTP monitoring, and full LLM debugging support.

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
      monitorHttp: true,               // default: true, set false to disable
      httpBufferCapacity: 100,         // default: 100
      enableInteraction: true,         // enable tap/scroll/text input
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

# Get device and environment information
dart run moinsen_runapp:moinsen_run device

# Get app lifecycle state and transition history
dart run moinsen_runapp:moinsen_run lifecycle

# Get HTTP/network traffic (all or errors only)
dart run moinsen_runapp:moinsen_run network
dart run moinsen_runapp:moinsen_run network --errors --last 10

# Inspect registered app state
dart run moinsen_runapp:moinsen_run inspect
dart run moinsen_runapp:moinsen_run inspect cart

# Capture a screenshot (saved as PNG)
dart run moinsen_runapp:moinsen_run screenshot

# Get full LLM-ready context (errors + logs + route + device + lifecycle + network + state)
dart run moinsen_runapp:moinsen_run context --with-screenshot --with-tree
```

### Interact with the running app (requires `enableInteraction: true`)

```bash
# See all interactive elements on screen
dart run moinsen_runapp:moinsen_run elements

# Tap by key, text, type, or coordinates
dart run moinsen_runapp:moinsen_run tap --key "submit_button"
dart run moinsen_runapp:moinsen_run tap --text "Sign In"
dart run moinsen_runapp:moinsen_run tap --x 200 --y 400

# Enter text into a field
dart run moinsen_runapp:moinsen_run enter-text --key "email" --input "user@example.com"

# Scroll until element is visible
dart run moinsen_runapp:moinsen_run scroll-to --key "footer"
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
| `device` | Get device and environment information |
| `lifecycle` | Get app lifecycle state and transition history |
| `network` | Get HTTP/network traffic (`--errors`, `--last N`) |
| `inspect` | Inspect registered app state (`inspect [key]`) |
| `screenshot` | Capture screen as PNG |
| `navigate` | Push a named route (`--push`) or pop (`--pop`) |
| `context` | Full LLM-ready context (`--with-screenshot`, `--with-tree`, `--log-count`, `--format`) |
| `status` | Check if app is running, show device and uptime |
| `reload` | Trigger hot reload |
| `restart` | Trigger hot restart (resets app state) |
| `state` | Dump widget tree via `debugDumpApp()` |
| `elements` | Get interactive elements on screen (requires `enableInteraction`) |
| `tap` | Tap element (`--key`, `--text`, `--type`, `--x`/`--y`) |
| `enter-text` | Enter text (`--key`/`--text`/`--type` + `--input`) |
| `scroll-to` | Scroll until visible (`--key`, `--text`) |
| `analyze` | Run `flutter analyze` with structured output |
| `stop` | Stop the running app |

## VM Service Extensions

In debug mode, `moinsenRunApp()` automatically registers VM Service extensions (13 core + 4 interaction when enabled):

| Extension | Returns |
|---|---|
| `ext.moinsen.getErrors` | `{errors: [...], totalCount, uniqueCount}` |
| `ext.moinsen.clearErrors` | `{cleared: true}` |
| `ext.moinsen.getInfo` | `{package, errorCount, uniqueErrors, platform}` |
| `ext.moinsen.getLogs` | `{logs: [...], capacity, size}` |
| `ext.moinsen.getPrompt` | `{prompt: "# Enhanced Bug Report\n..."}` |
| `ext.moinsen.screenshot` | `{screenshot: "<base64>", width, height}` |
| `ext.moinsen.getRoute` | `{currentRoute, observerInstalled, history: [...]}` |
| `ext.moinsen.navigate` | `{navigated: true, action, route}` |
| `ext.moinsen.getContext` | `{errors, logs, route, device, lifecycle, network, state, ...}` |
| `ext.moinsen.getDeviceInfo` | `{os, logicalWidth, logicalHeight, devicePixelRatio, locale, platformBrightness, accessibilityFeatures, ...}` |
| `ext.moinsen.getLifecycle` | `{currentState, uptime_ms, history: [...]}` |
| `ext.moinsen.getNetwork` | `{totalCount, errorCount, avgDuration_ms, requests: [...]}` |
| `ext.moinsen.getState` | `{registeredKeys: [...], states: {...}}` |

With `enableInteraction: true`, four additional extensions are registered:

| Extension | Returns |
|---|---|
| `ext.moinsen.getInteractiveElements` | `{elements: [{type, key, text, bounds, visible}], count}` |
| `ext.moinsen.tap` | `{success: true}` (params: `key`/`text`/`type`/`x`+`y`) |
| `ext.moinsen.enterText` | `{success: true}` (params: `key`/`text`/`type` + `input`) |
| `ext.moinsen.scrollTo` | `{success: true}` (params: `key`/`text`) |

These extensions are what the CLI tool and MCP server use under the hood. Any tool that speaks the Dart VM Service Protocol can call them directly.

## UI Interaction (opt-in)

Enable remote UI control for AI agents and testing:

```dart
moinsenRunApp(
  config: const RunAppConfig(
    enableInteraction: true,
  ),
  child: const MyApp(),
);
```

This registers 4 additional VM extensions for discovering and interacting with widgets. Elements are matched by key (most reliable), text content, widget type, or screen coordinates.

### Custom Widget Support

```dart
moinsenRunApp(
  config: RunAppConfig(
    enableInteraction: true,
    interactionConfig: InteractionConfig(
      isInteractiveWidget: (type) => type == MyCustomButton,
      extractText: (widget) {
        if (widget is MyLabel) return widget.title;
        return null;
      },
    ),
  ),
  child: const MyApp(),
);
```

All standard Flutter widgets (ElevatedButton, TextField, Text, etc.) are supported automatically. The callbacks extend support to app-specific custom widgets.

## MCP Server

The `moinsen_mcp` executable exposes all capabilities as MCP tools for AI agents:

```bash
dart run moinsen_runapp:moinsen_mcp
```

### Claude Code / Cursor Integration

Add to your MCP configuration:

```json
{
  "mcpServers": {
    "moinsen": {
      "command": "dart",
      "args": ["run", "moinsen_runapp:moinsen_mcp"],
      "cwd": "/path/to/your-flutter-project"
    }
  }
}
```

### 21 MCP Tools

| Category | Tools |
|----------|-------|
| Connection | `connect`, `disconnect` |
| Observation | `get_errors`, `clear_errors`, `get_logs`, `get_route`, `get_device_info`, `get_lifecycle`, `get_network`, `get_state`, `take_screenshot`, `get_prompt` |
| Interaction | `get_interactive_elements`, `tap`, `enter_text`, `scroll_to` |
| Control | `navigate`, `hot_reload`, `hot_restart` |
| Composite | `observe` (full context + screenshot in one call), `interact_and_verify` (action + verification screenshot) |

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

## Device & Environment Info

Automatically collected at query time — no configuration needed. Gives LLMs the context to diagnose layout bugs:

```json
{
  "os": "android",
  "osVersion": "14",
  "dartVersion": "3.11.3",
  "devicePixelRatio": 3.0,
  "logicalWidth": 393.0,
  "logicalHeight": 851.0,
  "locale": "de-DE",
  "textScaleFactor": 1.0,
  "platformBrightness": "dark",
  "accessibilityFeatures": {
    "boldText": false,
    "highContrast": false,
    "disableAnimations": false,
    "reduceMotion": false
  }
}
```

When an LLM sees `RenderFlex overflowed by 42 pixels`, it now knows whether the device is a 320px phone in landscape or a tablet.

## App Lifecycle Tracking

`MoinsenLifecycleObserver` is automatically registered by `moinsenRunApp()`. It tracks `AppLifecycleState` transitions:

```json
{
  "currentState": "resumed",
  "uptime_ms": 342500,
  "history": [
    {"state": "inactive", "previousState": "resumed", "timestamp": "..."},
    {"state": "paused", "previousState": "inactive", "timestamp": "..."},
    {"state": "resumed", "previousState": "paused", "timestamp": "..."}
  ]
}
```

When an LLM sees `WebSocket disconnected`, it can now check: "The app went to background 2 seconds before the error."

## HTTP/Network Monitoring

All `dart:io` HTTP traffic is automatically intercepted via `HttpOverrides`. This also captures traffic from `package:http` and `package:dio` since they use `HttpClient` internally.

```json
{
  "totalCount": 12,
  "errorCount": 1,
  "avgDuration_ms": 187,
  "requests": [
    {
      "method": "GET",
      "url": "https://api.example.com/users",
      "statusCode": 200,
      "duration_ms": 142,
      "timestamp": "2026-03-23T14:32:05.000"
    },
    {
      "method": "POST",
      "url": "https://api.example.com/auth",
      "statusCode": 500,
      "duration_ms": 340,
      "error": "Internal Server Error",
      "timestamp": "2026-03-23T14:32:06.000"
    }
  ]
}
```

**Security:** `Authorization`, `Cookie`, `Set-Cookie`, and `Proxy-Authorization` headers are automatically redacted to `[REDACTED]` before storage. Request/response bodies are never stored.

Disable HTTP monitoring with `RunAppConfig(monitorHttp: false)`.

## State Inspection

Register snapshot functions to expose app state to LLM tools:

```dart
// Register state providers (lazy — only called when queried)
moinsenExposeState('cart', () => cartBloc.state.toJson());
moinsenExposeState('user', () => {
  'name': userRepo.currentUser?.name,
  'isAuthenticated': authService.isLoggedIn,
});

// Remove when no longer needed
moinsenHideState('cart');
```

Query via CLI:

```bash
# Get all registered states
dart run moinsen_runapp:moinsen_run inspect

# Get a specific state
dart run moinsen_runapp:moinsen_run inspect cart
```

Works with any state management — Bloc, Riverpod, Provider, GetX, or plain Dart. The package has zero dependency on any state management library.

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
  │ moinsen_run device│               │  Your App (ErrorBoundaryWidget)  │
  │ moinsen_run network               │  MoinsenNavigatorObserver        │
  │ moinsen_run inspect               │  MoinsenLifecycleObserver        │
  │ moinsen_run context│              │  MoinsenHttpMonitor (HttpOverrides)
  └────────┬─────────┘               │  moinsenLog() → LogBuffer        │
           │                          │  moinsenExposeState() → Registry │
  .moinsen_run.json                   └──────────────┬───────────────────┘
  (VM Service URI, PID)                              │
                                      All errors funnel into:
                                                     ▼
                                      ┌─────────────────────────┐
                                      │      ErrorBucket        │ ← dedup by hash
                                      └────────────┬────────────┘
                                                   │
                      ┌────────────────┬───────────┼──────────────────────┐
                      ▼                ▼           ▼                      ▼
            ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
            │  ErrorObserver   │  │    LogBuffer     │  │  VM Extensions   │
            │ (ChangeNotifier) │  │ (ring buffer,    │  │ ext.moinsen.*    │
            └────────┬─────────┘  │  capacity 200)   │  │ (13 endpoints)   │
                     │            └──────────────────┘  └──────────────────┘
            ┌────────▼─────────┐         ▲
            │  ErrorBoundary   │         │
            │  Widget (Stack)  │   ScreenshotService    DeviceInfoCollector
            └──────────────────┘   NavigatorObserver     LifecycleObserver
                                   HttpMonitor           StateRegistry
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
10. **Lifecycle observer** records `AppLifecycleState` transitions (resumed, paused, inactive, etc.) for diagnosing background-related bugs.
11. **HTTP monitor** intercepts all `dart:io` HTTP traffic via `HttpOverrides`, recording method, URL, status, duration, and sanitized headers.
12. **State registry** holds lazy snapshot functions registered via `moinsenExposeState()`, called only when an LLM queries state.
13. **Device info collector** reads screen dimensions, pixel ratio, locale, brightness, and accessibility features from `PlatformDispatcher`.
14. **VM Service extensions** expose thirteen `ext.moinsen.*` endpoints in debug mode, allowing external tools to query the full app context live via the Dart VM Service Protocol.

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
| `monitorHttp` | `true` | Intercept and record HTTP traffic via `HttpOverrides` |
| `httpBufferCapacity` | `100` | Maximum HTTP requests to retain in the ring buffer |
| `releaseScreenVariant` | `ErrorScreenVariant.friendly` | Built-in release error screen variant |
| `releaseScreenBuilder` | `null` | Custom release error screen — overrides `releaseScreenVariant` |
| `debugScreenBuilder` | `null` | Custom debug error screen — overrides the built-in debug overlay |

### `moinsenLog`

```dart
void moinsenLog(String message, {String? source, String level = 'info'})
```

Log a message to the shared log buffer. Messages appear in `ext.moinsen.getLogs`, `moinsen_run logs`, and are included in prompt/context output.

### `moinsenExposeState`

```dart
void moinsenExposeState(String key, dynamic Function() snapshotFn)
```

Register a lazy state snapshot function. Called only when an LLM queries state via `ext.moinsen.getState` or `moinsen_run inspect`.

### `moinsenHideState`

```dart
void moinsenHideState(String key)
```

Remove a state registration.

### `moinsenReportError`

Manually report caught errors through the full pipeline:

```dart
try {
  await riskyOperation();
} catch (e, stack) {
  moinsenReportError(e, stack, source: 'api');
}
```

### `MoinsenNavigatorObserver`

| Property / Method | Description |
|---|---|
| `MoinsenNavigatorObserver.instance` | Shared singleton instance |
| `currentRoute` | Current route name (or `null`) |
| `history` | Unmodifiable list of `RouteRecord` entries (last 20) |
| `pushNamed(route)` | Push a named route via the observer's navigator |
| `pop()` | Pop the current route |

### `MoinsenLifecycleObserver`

| Property / Method | Description |
|---|---|
| `MoinsenLifecycleObserver.instance` | Shared singleton instance |
| `currentState` | Current `AppLifecycleState` |
| `history` | Unmodifiable list of `LifecycleRecord` entries (last 50) |

### `MoinsenHttpMonitor`

| Property / Method | Description |
|---|---|
| `MoinsenHttpMonitor.instance` | Shared singleton instance |
| `requests` | Unmodifiable list of `HttpRecord` entries (last 100) |
| `totalCount` | Total number of recorded requests |
| `errorCount` | Number of failed requests (4xx, 5xx, connection errors) |
| `avgDurationMs` | Average request duration in milliseconds |

### `MoinsenStateRegistry`

| Property / Method | Description |
|---|---|
| `MoinsenStateRegistry.instance` | Shared singleton instance |
| `keys` | Registered state key names |
| `snapshot()` | Take a snapshot of all registered states |
| `snapshotKey(key)` | Take a snapshot of a specific state |
| `register(key, snapshotFn)` | Register a snapshot function |
| `unregister(key)` | Remove a registration |

### `DeviceInfoCollector`

| Method | Description |
|---|---|
| `DeviceInfoCollector.collect()` | Collect current device/environment info as `Map<String, dynamic>` |

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

### `RouteRecord`

| Property | Type | Description |
|---|---|---|
| `action` | `String` | `'push'`, `'pop'`, `'replace'`, or `'remove'` |
| `routeName` | `String?` | Route name from `RouteSettings.name` |
| `arguments` | `String?` | String representation of route arguments |
| `timestamp` | `DateTime` | When this navigation occurred |

### `LifecycleRecord`

| Property | Type | Description |
|---|---|---|
| `state` | `AppLifecycleState` | The new lifecycle state |
| `previousState` | `AppLifecycleState` | The state before this transition |
| `timestamp` | `DateTime` | When this transition occurred |

### `HttpRecord`

| Property | Type | Description |
|---|---|---|
| `method` | `String` | HTTP method (GET, POST, etc.) |
| `url` | `String` | Request URL |
| `statusCode` | `int?` | HTTP status code (null for connection errors) |
| `durationMs` | `int` | Request duration in milliseconds |
| `timestamp` | `DateTime` | When the request was made |
| `requestSize` | `int?` | Request body size in bytes |
| `responseSize` | `int?` | Response body size in bytes |
| `error` | `String?` | Error message (for failed requests) |
| `isError` | `bool` | `true` for 4xx, 5xx, or connection errors |

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

## Platform Support

| Platform | Supported |
|---|---|
| iOS | Yes |
| Android | Yes |
| macOS | Yes |
| Windows | Yes |
| Linux | Yes |
| Web | No (`dart:io` required for HTTP monitoring and platform detection) |

## License

MIT License. See [LICENSE](LICENSE) for details.
