import 'package:flutter/widgets.dart';

/// Tracks navigation events for external tooling access.
///
/// Add this observer to your app's navigator to enable route tracking
/// via the `ext.moinsen.getRoute` VM Service extension and the
/// `moinsen_run route` CLI command.
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [MoinsenNavigatorObserver.instance],
///   // ...
/// )
/// ```
class MoinsenNavigatorObserver extends NavigatorObserver {
  MoinsenNavigatorObserver._();

  static MoinsenNavigatorObserver? _instance;

  /// The shared observer instance.
  // Getter-based singleton — factory constructor would break the public API
  // (callers use `MoinsenNavigatorObserver.instance`).
  // ignore: prefer_constructors_over_static_methods
  static MoinsenNavigatorObserver get instance =>
      _instance ??= MoinsenNavigatorObserver._();

  /// Whether an observer instance has been created.
  static bool get isInstalled => _instance != null;

  /// Reset the singleton (for testing only).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  static const _historyCapacity = 20;

  final List<RouteRecord> _history = [];

  /// The current route name, or `null` if no routes have been observed.
  String? get currentRoute {
    if (_history.isEmpty) return null;
    // Walk backwards to find the last push/replace that wasn't popped.
    for (var i = _history.length - 1; i >= 0; i--) {
      final record = _history[i];
      if (record.action == 'push' || record.action == 'replace') {
        return record.routeName;
      }
    }
    return null;
  }

  /// Unmodifiable view of the navigation history.
  List<RouteRecord> get history => List.unmodifiable(_history);

  /// Serialize current state to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'currentRoute': currentRoute,
    'observerInstalled': true,
    'historyCount': _history.length,
    'history': _history.map((r) => r.toJson()).toList(),
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('push', route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('pop', route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _record('replace', newRoute);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _record('remove', route);
  }

  void _record(String action, Route<dynamic> route) {
    if (_history.length >= _historyCapacity) {
      _history.removeAt(0);
    }
    _history.add(
      RouteRecord(
        action: action,
        routeName: route.settings.name,
        arguments: route.settings.arguments?.toString(),
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Push a named route via the observer's navigator.
  ///
  /// Returns `true` if navigation succeeded, `false` if the navigator
  /// is not available (observer not attached to a Navigator).
  Future<bool> pushNamed(String route, {Object? arguments}) async {
    final nav = navigator;
    if (nav == null) return false;
    await nav.pushNamed<void>(route, arguments: arguments);
    return true;
  }

  /// Pop the current route.
  ///
  /// Returns `true` if the pop succeeded, `false` if the navigator
  /// is not available or cannot pop.
  bool pop() {
    final nav = navigator;
    if (nav == null) return false;
    if (!nav.canPop()) return false;
    nav.pop<void>();
    return true;
  }

  /// Clear the history (for testing).
  @visibleForTesting
  void clearHistory() => _history.clear();
}

/// A single navigation event.
class RouteRecord {
  const RouteRecord({
    required this.action,
    required this.timestamp,
    this.routeName,
    this.arguments,
  });

  /// The navigation action: 'push', 'pop', 'replace', or 'remove'.
  final String action;

  /// Route name from [RouteSettings.name].
  final String? routeName;

  /// String representation of route arguments.
  final String? arguments;

  /// When this navigation occurred.
  final DateTime timestamp;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'action': action,
    'routeName': routeName,
    if (arguments != null) 'arguments': arguments,
    'timestamp': timestamp.toIso8601String(),
  };
}
