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
