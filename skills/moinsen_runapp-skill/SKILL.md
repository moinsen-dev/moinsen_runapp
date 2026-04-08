---
name: moinsen_runapp-skill
description: Use when working with Flutter apps that use moinsen_runapp — for setup, configuration, state exposure, error reporting, HTTP monitoring, UI interaction (tap, scroll, text input), MCP server setup, and LLM-assisted debugging via CLI, VM Service extensions, or MCP tools.
---

# moinsen_runapp — LLM Debug Bridge for Flutter

Drop-in `runApp()` replacement that gives LLM tools full visibility and control over a Flutter app: three-layer error catching, app-level logging, navigation tracking, screenshots, device context, lifecycle tracking, HTTP monitoring, state inspection, remote UI interaction, and an MCP server for AI agent integration.

## When to Use This Skill

- Project has `moinsen_runapp` in pubspec.yaml
- User asks about Flutter error handling with LLM support
- User wants to make a Flutter app "debuggable by AI"
- User asks about exposing app state for debugging
- User asks about the `moinsen_run` CLI tool or `ext.moinsen.*` extensions
- User wants to remote-control a Flutter app (tap, scroll, enter text)
- User wants to connect an AI agent to a Flutter app via MCP
- User is configuring MCP servers for Flutter debugging

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

## Enable UI Interaction (Opt-In)

```dart
moinsenRunApp(
  config: const RunAppConfig(enableInteraction: true),
  child: const MyApp(),
);
```

Registers 4 additional VM extensions for tap, scroll, text input, and element discovery. Only active in debug mode.

### Custom Widget Support

```dart
RunAppConfig(
  enableInteraction: true,
  interactionConfig: InteractionConfig(
    isInteractiveWidget: (type) => type == MyCustomButton,
    shouldStopTraversal: (type) => type == MyCustomCard,
    extractText: (widget) {
      if (widget is MyLabel) return widget.title;
      return null;
    },
  ),
)
```

Built-in support for all standard Flutter widgets (buttons, text fields, switches, etc.).

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
| `enableInteraction` | `false` | Enable UI interaction extensions (tap, scroll, text, elements) |
| `interactionConfig` | `InteractionConfig()` | Callbacks for custom widget support (only when interaction enabled) |
| `releaseScreenVariant` | `friendly` | Error screen: `friendly`, `minimal`, or `illustrated` |
| `releaseScreenBuilder` | `null` | Custom release error screen (overrides variant) |
| `debugScreenBuilder` | `null` | Custom debug error screen (overrides built-in) |

## State Exposure Patterns

State snapshots are **lazy** — functions are only called when an LLM queries state.

```dart
// Bloc / Cubit
moinsenExposeState('auth', () => authBloc.state.toJson());

// Riverpod
moinsenExposeState('settings', () => ref.read(settingsProvider).toJson());

// Provider / ChangeNotifier
moinsenExposeState('cart', () => {
  'items': cartModel.items.length,
  'total': cartModel.totalPrice,
});

// Remove when no longer needed
moinsenHideState('cart');
```

## Error Reporting Integration

```dart
// Sentry
onError: (error, stack) => Sentry.captureException(error, stackTrace: stack),

// Crashlytics
onError: (error, stack) => FirebaseCrashlytics.instance.recordError(error, stack),

// Manual reporting from catch blocks:
try {
  await api.fetchData();
} catch (e, stack) {
  moinsenReportError(e, stack, source: 'api');
}
```

## CLI Quick Reference

Run with `dart run moinsen_runapp:moinsen_run <command>`.

### Observation Commands

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
| `context` | Full LLM-ready context report (`--with-screenshot`, `--with-tree`) |
| `status` | Check if app is running |
| `state` | Widget tree dump |
| `analyze` | Run `flutter analyze` |

### Interaction Commands (require `enableInteraction: true`)

| Command | Description |
|---|---|
| `elements` | Get all interactive elements currently on screen |
| `tap` | Tap element (`--key`, `--text`, `--type`, or `--x`/`--y`) |
| `enter-text` | Type into text field (`--key`/`--text`/`--type` + `--input`) |
| `scroll-to` | Scroll until element visible (`--key` or `--text`) |

### Control Commands

| Command | Description |
|---|---|
| `navigate` | Push (`--push /route`) or pop (`--pop`) |
| `reload` | Hot reload |
| `restart` | Hot restart |
| `stop` | Stop the running app |

## MCP Server

The `moinsen_mcp` executable exposes all capabilities as 21 MCP tools for AI agents.

### Setup

```bash
# Global install (recommended)
dart pub global activate moinsen_runapp
moinsen_mcp

# Or from a project
dart run moinsen_runapp:moinsen_mcp
```

### Claude Code / Cursor Integration

With global installation (recommended):

```json
{
  "mcpServers": {
    "moinsen": {
      "command": "moinsen_mcp"
    }
  }
}
```

Without global installation:

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

### CLI Options

| Flag | Default | Description |
|---|---|---|
| `--log-level`, `-l` | `INFO` | Log level (FINEST, FINE, INFO, WARNING, SEVERE) |
| `--log-file` | stderr | Path to log file |

### Typical MCP Workflow

```
1. connect(uri: "ws://127.0.0.1:8181/ws")    — connect to running app
2. observe()                                    — full context + screenshot
3. get_interactive_elements()                   — see what's tappable
4. tap(key: "login_button")                     — interact
5. interact_and_verify(action: "tap", key: "submit")  — action + screenshot
6. disconnect()
```

### MCP Tool Reference (21 Tools)

| Category | Tools |
|----------|-------|
| Connection | `connect`, `disconnect` |
| Observation | `get_errors`, `clear_errors`, `get_logs`, `get_route`, `get_device_info`, `get_lifecycle`, `get_network`, `get_state`, `take_screenshot`, `get_prompt` |
| Interaction | `get_interactive_elements`, `tap`, `enter_text`, `scroll_to` |
| Control | `navigate`, `hot_reload`, `hot_restart` |
| Composite | `observe` (full context + screenshot in one call), `interact_and_verify` (action + verification screenshot) |

### MCP Usage Patterns

**Quick health check:** `connect` -> `observe` -> `disconnect`

**Automated form filling:**
```
connect -> get_interactive_elements -> enter_text(key: "email", input: "...") -> tap(key: "submit") -> take_screenshot -> disconnect
```

**Debug a crash:**
```
connect -> get_errors -> get_logs -> get_network -> get_route -> take_screenshot -> disconnect
```

## VM Service Extensions

All registered under `ext.moinsen.*` in debug mode.

### Observation Extensions (13, always active)

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

### Interaction Extensions (4, require `enableInteraction: true`)

| Extension | Params | Returns |
|---|---|---|
| `getInteractiveElements` | *(none)* | `{elements: [{type, key, text, bounds, visible}], count}` |
| `tap` | `key`/`text`/`type`/`x`+`y` | `{success: true}` or `{success: false, error}` |
| `enterText` | `key`/`text`/`type` + `input` | `{success: true}` or `{success: false, error}` |
| `scrollTo` | `key`/`text` | `{success: true}` or `{success: false, error}` |

**Widget matching precedence:** coordinates (x+y) > key > text > type. All params are strings.

## InteractionConfig Reference

| Callback | Purpose |
|---|---|
| `isInteractiveWidget(Type)` | Mark custom widgets as interactive |
| `shouldStopTraversal(Type)` | Stop traversing children of this widget |
| `extractText(Widget)` | Extract text from custom widgets |

Built-in interactive widgets: `ElevatedButton`, `TextButton`, `FilledButton`, `OutlinedButton`, `IconButton`, `FloatingActionButton`, `TextField`, `TextFormField`, `Checkbox`, `Switch`, `Radio`, `Slider`, `GestureDetector`, `InkWell`, `DropdownButton`, `PopupMenuButton`, and their ListTile variants.

## Troubleshooting

**Navigation not tracked / `route` returns null:**
- Forgot `MoinsenNavigatorObserver.instance` in `navigatorObservers`
- Using Navigator 2.0 (Router) — observer is for Navigator 1.0 only

**HTTP requests not showing:**
- `monitorHttp: false` in config
- Custom `HttpOverrides` set after `moinsenRunApp()` — chain via `MoinsenHttpOverrides(previous: yourOverrides)`

**CLI commands fail with "No running app found":**
- App not started with `moinsen_run start`, or `.moinsen_run.json` stale

**Interaction commands return errors:**
- `enableInteraction: false` (default) — must enable
- App not in debug mode
- Widget not found — use `elements` to see what's on screen

**`elements` returns empty list:**
- No interactive widgets on screen
- Elements obscured by overlays
- Custom widgets not registered via `InteractionConfig`

**MCP: "Not connected to any app":**
- Call `connect` first with the VM service URI

**MCP: "No isolate with ext.moinsen.getErrors found":**
- App doesn't use `moinsenRunApp()`
- App in release mode — extensions only register in debug mode

**MCP: Connection drops after hot restart:**
- Hot restart reinitializes the VM — reconnect after `hot_restart`

## Architecture Notes

- **No custom binding** — uses `dart:developer.registerExtension` and `GestureBinding.instance`, compatible with any Flutter binding
- **Interaction is opt-in** — `enableInteraction: false` by default
- **Widget matching** — sealed class with 4 strategies: `CoordinatesMatcher` (fastest), `KeyMatcher`, `TextMatcher`, `TypeStringMatcher`
- **MCP transport** — stdio only, auto-discovers moinsen-enabled isolate

## Platform Support

| Platform | Supported |
|---|---|
| iOS / Android / macOS / Windows / Linux | Yes |
| Web | No (`dart:io` required) |

## Package Info

- **Package:** moinsen_runapp
- **Version:** 0.6.0
- **Executables:** `moinsen_run` (CLI), `moinsen_mcp` (MCP server)
- **Repository:** https://github.com/moinsen-dev/moinsen_runapp
- **License:** MIT
