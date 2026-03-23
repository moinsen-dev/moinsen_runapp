---
name: moinsen-runapp
description: Use when working with Flutter apps that use moinsen_runapp — for initial setup, configuration, state exposure, error reporting integration, HTTP monitoring, and LLM-assisted debugging via CLI or VM Service extensions.
---

# moinsen_runapp — LLM Debug Bridge for Flutter

Drop-in `runApp()` replacement that gives LLM tools full visibility into a Flutter app: three-layer error catching, app-level logging, navigation tracking, screenshots, device context, lifecycle tracking, HTTP monitoring, and state inspection. Zero-config, one-line integration.

## When to Use This Skill

- Project has `moinsen_runapp` in pubspec.yaml
- User asks about Flutter error handling with LLM support
- User wants to make a Flutter app "debuggable by AI"
- User asks about exposing app state for debugging
- User asks about the `moinsen_run` CLI tool or `ext.moinsen.*` extensions

## Quick Start (4 Steps)

### 1. Replace `runApp()`

```dart
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  moinsenRunApp(child: const MyApp());
}
```

### 2. Add Navigator Observer

```dart
MaterialApp(
  navigatorObservers: [MoinsenNavigatorObserver.instance],
  // ...
)
```

### 3. Log App Events

```dart
moinsenLog('Payment completed', source: 'checkout', level: 'info');
moinsenLog('API returned 500', source: 'api', level: 'error');
```

### 4. Expose State (Optional)

```dart
moinsenExposeState('cart', () => cartBloc.state.toJson());
moinsenExposeState('user', () => {'name': user.name, 'role': user.role});
```

That's it. The app now has error catching, logging, route tracking, device info, lifecycle tracking, HTTP monitoring, and LLM debugging support.

## With Async Initialization

```dart
void main() {
  moinsenRunApp(
    init: () async {
      await Firebase.initializeApp();
      await Hive.initFlutter();
    },
    onError: (error, stack) => Sentry.captureException(error, stackTrace: stack),
    config: const RunAppConfig(
      releaseScreenVariant: ErrorScreenVariant.minimal,
      logToFile: true,
    ),
    child: const MyApp(),
  );
}
```

If `init` throws, the error is caught and logged — but the app **always starts**.

## RunAppConfig Reference

| Parameter | Default | Description |
|---|---|---|
| `deduplicationWindow` | `Duration(seconds: 2)` | Time window for deduplicating identical errors |
| `maxLoggedErrors` | `50` | Max unique errors tracked before evicting oldest |
| `logBufferCapacity` | `200` | Max app-level log entries retained |
| `logToFile` | `false` | Write errors to disk (auto-rotates at 1 MB) |
| `logFilePath` | `null` | Explicit path; auto-resolved via path_provider if null |
| `screenshotMaxDimension` | `null` | Cap screenshot resolution (physical pixels) |
| `monitorHttp` | `true` | Intercept all dart:io HTTP traffic |
| `httpBufferCapacity` | `100` | Max HTTP requests retained in ring buffer |
| `releaseScreenVariant` | `friendly` | Error screen: `friendly`, `minimal`, or `illustrated` |
| `releaseScreenBuilder` | `null` | Custom release error screen (overrides variant) |
| `debugScreenBuilder` | `null` | Custom debug error screen (overrides built-in) |

## State Exposure Patterns

State snapshots are **lazy** — functions are only called when an LLM queries state.

### Bloc / Cubit
```dart
moinsenExposeState('auth', () => authBloc.state.toJson());
```

### Riverpod
```dart
// Inside a ConsumerWidget or with ref access:
moinsenExposeState('settings', () => ref.read(settingsProvider).toJson());
```

### Provider / ChangeNotifier
```dart
moinsenExposeState('cart', () => {
  'items': cartModel.items.length,
  'total': cartModel.totalPrice,
});
```

### Remove When No Longer Needed
```dart
moinsenHideState('cart');
```

## Error Reporting Integration

```dart
// Sentry
onError: (error, stack) => Sentry.captureException(error, stackTrace: stack),

// Crashlytics
onError: (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack),

// Manual reporting from catch blocks (goes through full pipeline):
try {
  await api.fetchData();
} catch (e, stack) {
  moinsenReportError(e, stack, source: 'api');
}
```

## CLI Quick Reference

Run with `dart run moinsen_runapp:moinsen_run <command>`.

| Command | Description |
|---|---|
| *(default)* | Start `flutter run` with JSON line streaming |
| `errors` | Get deduplicated error report |
| `prompt` | LLM-ready markdown bug report |
| `logs` | Recent log entries (`--last N`) |
| `route` | Current route + navigation history |
| `device` | Device/environment info (screen, locale, a11y) |
| `lifecycle` | App lifecycle state + transitions |
| `network` | HTTP traffic (`--errors`, `--last N`) |
| `inspect` | Registered app state (`inspect [key]`) |
| `screenshot` | Capture screen as PNG |
| `navigate` | Push (`--push /route`) or pop (`--pop`) |
| `context` | Full LLM-ready context report (`--with-screenshot`, `--with-tree`, `--format json`) |
| `status` | Check if app is running |
| `reload` | Hot reload |
| `restart` | Hot restart |
| `state` | Widget tree dump |
| `analyze` | Run `flutter analyze` |
| `stop` | Stop the running app |

### The "Tell Me Everything" Command

```bash
dart run moinsen_runapp:moinsen_run context --with-screenshot --with-tree
```

Returns a single markdown document with: errors, logs, device info, lifecycle state, HTTP traffic, navigation history, app state, widget tree, screenshot path, and available actions.

## VM Service Extensions (13)

All registered under `ext.moinsen.*` in debug mode.

| Extension | Returns |
|---|---|
| `getErrors` | `{errors: [...], totalCount, uniqueCount}` |
| `clearErrors` | `{cleared: true}` |
| `getInfo` | `{package, errorCount, uniqueErrors, platform}` |
| `getLogs` | `{logs: [...], capacity, size}` |
| `getPrompt` | `{prompt: "# Enhanced Bug Report\n..."}` |
| `screenshot` | `{screenshot: "<base64>", width, height}` |
| `getRoute` | `{currentRoute, observerInstalled, history: [...]}` |
| `navigate` | `{navigated: true, action, route}` (params: `route`, `pop`) |
| `getContext` | `{errors, logs, route, device, lifecycle, network, state}` |
| `getDeviceInfo` | `{os, logicalWidth, logicalHeight, devicePixelRatio, locale, ...}` |
| `getLifecycle` | `{currentState, uptime_ms, history: [...]}` |
| `getNetwork` | `{totalCount, errorCount, avgDuration_ms, requests: [...]}` |
| `getState` | `{registeredKeys: [...], states: {...}}` (param: `key`) |

## Common Patterns

### Custom Error Screen

```dart
moinsenRunApp(
  config: RunAppConfig(
    releaseScreenBuilder: (context, errors) => YourErrorScreen(errors: errors),
    debugScreenBuilder: (context, errors) => YourDebugScreen(errors: errors),
  ),
  child: const MyApp(),
);
```

### Disable HTTP Monitoring

```dart
const RunAppConfig(monitorHttp: false)
```

Useful when using a custom HTTP client wrapper that conflicts with `HttpOverrides`.

### Log Levels

```dart
moinsenLog('User logged in', source: 'auth', level: 'info');     // default
moinsenLog('Token expiring soon', source: 'auth', level: 'warning');
moinsenLog('Login failed', source: 'auth', level: 'error');
```

### Screenshot with Custom Resolution

```dart
final result = await ScreenshotService.capture(
  pixelRatio: 1.0,        // 1x instead of device ratio
  maxDimension: 800,       // cap at 800px
);
```

## Troubleshooting

**Navigation not tracked / `route` returns null:**
- Forgot to add `MoinsenNavigatorObserver.instance` to `navigatorObservers` in `MaterialApp`
- Using `Navigator 2.0` (Router) — observer is for `Navigator 1.0` only

**HTTP requests not showing in `network`:**
- `monitorHttp: false` in config
- Using a custom `HttpOverrides` that was set AFTER `moinsenRunApp()` — set yours before, or chain via `MoinsenHttpOverrides(previous: yourOverrides)`
- Web platform — `dart:io` not available on web

**`inspect` returns empty states:**
- No `moinsenExposeState()` calls registered
- Called `moinsenHideState()` before querying
- Snapshot function throws — check for null references

**CLI commands fail with "No running app found":**
- App not started with `moinsen_run start` (or `.moinsen_run.json` missing)
- App crashed and state file is stale — delete `.moinsen_run.json` and restart

**Errors not showing on error screen:**
- Error screen auto-pauses capture while visible — dismiss to resume
- `maxLoggedErrors` reached (default 50) — oldest are evicted

**File logging not working:**
- `logToFile: false` (default) — must explicitly enable
- No write permission to resolved path — set `logFilePath` explicitly

## Platform Support

| Platform | Supported |
|---|---|
| iOS / Android / macOS / Windows / Linux | Yes |
| Web | No (`dart:io` required) |

## Package Info

- **Package:** moinsen_runapp
- **Version:** ^0.5.0
- **Repository:** https://github.com/moinsen-dev/moinsen_runapp
- **License:** MIT
- **Dependencies:** flutter, args, path_provider, vm_service (no external deps)
