## 0.7.1

### Added

- **`pregrant` Android support.** The command now auto-detects platform from
  the device id format (36-char hex-with-dashes → iOS UDID, otherwise Android
  adb serial) and runs `adb -s <serial> shell pm grant <package> <perm>` per
  service. Service names (`camera`, `location`, `microphone`, ...) are mapped
  to the right Android permission constant internally; services without an
  Android counterpart are skipped with a clear note in the result.
- Auto-detect of Android `applicationId` from `android/app/build.gradle.kts`
  or `android/app/build.gradle` when `--bundle-id` is omitted (mirrors the
  iOS bundle-id auto-detection from `ios/Runner.xcodeproj`).

## 0.7.0 — Foundation: robust agentic Flutter testing

Round of CLI hardening driven by real-world Claude Code session friction (curated_closet, May 2026). The big themes: race-conditions on `tap` after navigation, no inline screenshot for LLM prompts, stale state file after external kill, system permission dialogs blocking automation.

### Added

- **`screenshot --base64`** — Return PNG bytes inline as JSON (`{base64, width, height, bytes}`) instead of writing to disk. Drops the `cp screenshot.png ... | sips ...` dance from agent scripts.
- **`await-route <path> [--timeout 5s] [--startsWith]`** — Poll the running app's current route until it matches, then exit. Unblocks scripts that tap a navigation button and need to wait for the destination route to settle.
- **`await-element [--key|--text] [--timeout 5s]`** — Poll the interactive element list until a target widget is present and visible. Companion to `await-route` for when the route already matches but the widget tree is mid-rebuild.
- **`pregrant`** — Pre-approve iOS Simulator privacy permissions via `xcrun simctl privacy`. Camera/Location/Photos/Microphone dialogs never appear, removing the #1 native-dialog blocker for automated onboarding tests. Auto-detects UDID from `.moinsen_run.json` and bundle-id from `ios/Runner.xcodeproj`.
- **`start --device <id>` / `-d`** — Direct flag, no more `moinsen_run start -- -d <id>` passthrough dance. The `--`-passthrough still works for ad-hoc args.
- **`tap` / `enter-text` / `scroll-to` retry-with-backoff** — 3 attempts, exponential backoff (200ms → 400ms → 800ms, total ≤1.5s) on `KeyMatcher: not found`-class errors. Solves the silent-fail-after-restart class. Opt out per call with `--no-retry`.

### Changed

- Stale `.moinsen_run.json` is now detected via `kill -0 <pid>` before each VM-Service call. The state file is auto-cleaned and the user gets a clear "App not running" error instead of a generic "Failed to connect to VM Service".

## 0.6.3

- Document global installation via `dart pub global activate moinsen_runapp` for `moinsen_run` and `moinsen_mcp` executables.
- Simplify MCP server configuration with global install (just `"command": "moinsen_mcp"`).

## 0.6.2

- Add `install-skill` CLI command for installing the AI agent skill directly into `.claude/skills/` or `.cursor/skills/` (project or global level).

## 0.6.1

- Fix skill directory naming to match `skills` package convention (`moinsen_runapp-skill` instead of `moinsen-runapp`).

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
