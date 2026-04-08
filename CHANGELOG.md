## 0.6.0 — Remote Control & MCP Server

moinsen_runapp evolves from observation-only to full remote control. AI agents can now see what's on screen, tap buttons, enter text, scroll, and verify results — all through VM Service extensions, CLI commands, or the new MCP server.

### Added

- **UI Interaction** (opt-in via `enableInteraction: true`) — Remote-control the app through 4 new VM extensions and CLI commands:
  - `ext.moinsen.getInteractiveElements` / `moinsen_run elements` — Discover all interactive widgets on screen with type, key, text, bounds, and visibility
  - `ext.moinsen.tap` / `moinsen_run tap` — Tap elements by key, text, widget type, or screen coordinates
  - `ext.moinsen.enterText` / `moinsen_run enter-text` — Type text into fields via controller manipulation
  - `ext.moinsen.scrollTo` / `moinsen_run scroll-to` — Scroll until a target element becomes visible (max 50 attempts)
- **Widget Matching** — 4-strategy sealed class: `CoordinatesMatcher` (fastest, skips tree), `KeyMatcher`, `TextMatcher`, `TypeStringMatcher`. Precedence: coordinates > key > text > type.
- **InteractionConfig** — Extensible widget support via callbacks: `isInteractiveWidget`, `shouldStopTraversal`, `extractText`. Built-in support for all standard Flutter widgets (buttons, text fields, switches, etc.).
- **MCP Server** (`moinsen_mcp` executable) — Model Context Protocol server exposing all 17 extensions as MCP tools for AI agents (Claude Code, Cursor, etc.). Includes 2 composite tools:
  - `observe` — Full context + screenshot + interactive elements in one call
  - `interact_and_verify` — Execute action, wait 300ms, take verification screenshot
- **Enhanced Context Report** — `getContext` and `generateContext` now include an `## Interactive Elements` section and expanded `## Available Actions` when interaction is enabled.

### RunAppConfig (2 new fields)

| Field | Default | Description |
|-------|---------|-------------|
| `enableInteraction` | `false` | Enable UI interaction VM extensions |
| `interactionConfig` | `InteractionConfig()` | Callbacks for custom widget support |

### CLI commands (4 new, 24 total)

| Command | Description |
|---------|-------------|
| `elements` | Get interactive elements on screen |
| `tap` | Tap element (`--key`, `--text`, `--type`, `--x`/`--y`) |
| `enter-text` | Enter text (`--key`/`--text`/`--type` + `--input`) |
| `scroll-to` | Scroll until visible (`--key`, `--text`) |

### VM Service extensions (4 new, 17 total)

| Extension | Description |
|-----------|-------------|
| `ext.moinsen.getInteractiveElements` | Interactive widget discovery |
| `ext.moinsen.tap` | Tap by key/text/type/coordinates |
| `ext.moinsen.enterText` | Text input via controller |
| `ext.moinsen.scrollTo` | Scroll until visible |

### MCP Server (21 tools)

New `moinsen_mcp` executable: `dart run moinsen_runapp:moinsen_mcp`

| Category | Tools |
|----------|-------|
| Connection | `connect`, `disconnect` |
| Observation | `get_errors`, `clear_errors`, `get_logs`, `get_route`, `get_device_info`, `get_lifecycle`, `get_network`, `get_state`, `take_screenshot`, `get_prompt` |
| Interaction | `get_interactive_elements`, `tap`, `enter_text`, `scroll_to` |
| Control | `navigate`, `hot_reload`, `hot_restart` |
| Composite | `observe`, `interact_and_verify` |

### Architecture

- No custom binding — interaction uses `GestureBinding.instance`, compatible with any Flutter binding
- Hit-test validation ensures only actually interactable elements are reported
- Element tree traversal with configurable stop rules and text extraction
- Gesture dispatch via low-level `PointerEvent` records (tap + drag)

---

## 0.5.0 — Agentic Ready

moinsen_runapp now provides the full environmental context an LLM needs to diagnose and fix Flutter app issues — not just what went wrong, but why.

### Added

- **Device & Environment Info** — Screen dimensions, pixel ratio, locale, brightness, text scale factor, OS version, Dart version, and accessibility features. Exposed via `ext.moinsen.getDeviceInfo` VM extension and `moinsen_run device` CLI command. Now an LLM knows whether a `RenderFlex overflow` is a small-phone problem or a tablet layout bug.
- **App Lifecycle Tracking** — `MoinsenLifecycleObserver` automatically tracks `AppLifecycleState` transitions (resumed, inactive, paused, detached, hidden) with timestamps. Exposed via `ext.moinsen.getLifecycle` and `moinsen_run lifecycle`. Helps diagnose "WebSocket disconnected" bugs caused by background transitions.
- **HTTP/Network Traffic Monitor** — Zero-config HTTP interception via `HttpOverrides`. Records method, URL, status code, duration, and sanitized headers (Authorization/Cookie automatically redacted). Ring buffer of last 100 requests. Exposed via `ext.moinsen.getNetwork` and `moinsen_run network [--errors] [--last N]`. Opt-out via `RunAppConfig.monitorHttp`.
- **State Inspection Registry** — Opt-in API for exposing app state to LLM tools. `moinsenExposeState('cart', () => cartBloc.state.toJson())` registers lazy snapshot functions called only when queried. Exposed via `ext.moinsen.getState` and `moinsen_run inspect [key]`.
- **Enriched Context Report** — `ext.moinsen.getContext` and `moinsen_run context` now include device info, lifecycle state, network traffic, and app state alongside errors, logs, and navigation. New `## Available Actions` section tells the LLM what it can do.

### CLI commands (4 new, 20 total)

| Command | Description |
|---------|------------|
| `device` | Get device and environment information |
| `lifecycle` | Get app lifecycle state and transition history |
| `network` | Get HTTP/network traffic (`--errors`, `--last N`) |
| `inspect` | Inspect registered app state (`inspect [key]`) |

### VM Service extensions (4 new, 13 total)

| Extension | Description |
|-----------|------------|
| `ext.moinsen.getDeviceInfo` | Device context (screen, locale, a11y) |
| `ext.moinsen.getLifecycle` | Lifecycle state and transition history |
| `ext.moinsen.getNetwork` | HTTP traffic ring buffer |
| `ext.moinsen.getState` | Registered app state snapshots |

### New public API

- `moinsenExposeState(key, snapshotFn)` — Register state for LLM access
- `moinsenHideState(key)` — Remove state registration
- `RunAppConfig.monitorHttp` — Enable/disable HTTP monitoring (default: true)
- `RunAppConfig.httpBufferCapacity` — HTTP ring buffer size (default: 100)

## 0.4.0 — LLM Debug Bridge

moinsen_runapp is now the universal LLM debug bridge for Flutter apps.

### Added

- **`moinsenLog()`** — App-level logging API. Surface navigation events, API calls, and state changes to external tooling. Messages appear in `ext.moinsen.getLogs` and the `moinsen_run logs` CLI command.
- **`MoinsenNavigatorObserver`** — Drop-in `NavigatorObserver` that tracks route changes. Exposes current route, navigation history, and programmatic navigation via `pushNamed()` / `pop()`.
- **Screenshot capture** — New `ext.moinsen.screenshot` VM Service extension and `moinsen_run screenshot` CLI command. Captures the current screen as PNG using the render view's layer tree directly (no `RepaintBoundary` wrapper needed).
- **Route information** — New `ext.moinsen.getRoute` VM Service extension and `moinsen_run route` CLI command. Returns current route, observer status, and navigation history.
- **Navigation control** — New `ext.moinsen.navigate` VM Service extension and `moinsen_run navigate` CLI command. Push named routes or pop programmatically (debug mode only).
- **Context command** — New `moinsen_run context` CLI command — the "tell me everything" endpoint. Aggregates errors, logs, route info, optional screenshot, and widget tree into a single LLM-ready markdown document. Supports `--with-screenshot`, `--with-tree`, `--log-count`, and `--format` (markdown/json).
- **Enhanced prompt** — `ext.moinsen.getPrompt` now includes recent logs and navigation history alongside errors for richer LLM-assisted debugging.
- **`RunAppConfig.logBufferCapacity`** — Configure log buffer size (default: 200).
- **`RunAppConfig.screenshotMaxDimension`** — Cap screenshot resolution for memory safety.

### CLI commands (6 new, 16 total)

| Command | Description |
|---------|------------|
| `screenshot` | Capture a screenshot from the running app |
| `route` | Get the current route and navigation history |
| `navigate` | Push a route or pop the current route |
| `context` | Get a comprehensive LLM-ready context report |
| *(existing)* | `start`, `stop`, `status`, `errors`, `logs`, `prompt`, `reload`, `restart`, `state`, `analyze` |

### VM Service extensions (4 new, 9 total)

| Extension | Description |
|-----------|------------|
| `ext.moinsen.screenshot` | Capture screen as base64 PNG |
| `ext.moinsen.getRoute` | Current route and navigation history |
| `ext.moinsen.navigate` | Push/pop routes programmatically |
| `ext.moinsen.getContext` | Aggregated context (errors + logs + route) |
| *(existing)* | `getErrors`, `clearErrors`, `getInfo`, `getLogs`, `getPrompt` |

## 0.3.0

- Add `moinsen_run` CLI tool for live LLM-assisted debugging via VM Service
- Register 5 VM Service extensions in debug mode: `ext.moinsen.getErrors`, `clearErrors`, `getInfo`, `getLogs`, `getPrompt`
- Add `LogBuffer` ring buffer for structured log capture (capacity 200)
- Extract `generateBugReport()` from debug screen into reusable prompt generator
- Add `ErrorEntry.toJson()` for structured error serialization
- CLI commands: `start`, `stop`, `status`, `errors`, `logs`, `prompt`, `reload`, `restart`, `state`, `analyze`
- All CLI output is structured JSON for machine consumption

## 0.2.0

- Add `moinsenReportError()` top-level function for manually reporting caught errors through the full error pipeline (dedup, console log, file log, UI notification, external callback)
- Add `ErrorCatcher.reportError()` public method as the underlying API
- Add `setupTestErrorCatcher()` and `resetGlobalErrorCatcher()` test helpers
- Errors from state management (Riverpod, Bloc, etc.), API calls, and background tasks can now be unified with the automatic three-layer error catching

## 0.1.0

- Three-layer error catching: Flutter framework, platform dispatcher, and zone guard
- Error deduplication with configurable time window
- Beautiful release error screens: friendly, minimal, and illustrated variants
- Custom error screen builders for release and debug modes
- Error observer (`ChangeNotifier`) for reactive UI updates
- Optional file logging with auto-resolved or explicit paths
- `onError` callback for external reporting (Sentry, Crashlytics, etc.)
- App always starts regardless of init errors
- `ErrorBoundaryWidget` wraps the app tree for inline error display
