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
