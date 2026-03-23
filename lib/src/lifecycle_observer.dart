import 'package:flutter/widgets.dart';

/// Tracks app lifecycle state transitions for LLM context.
///
/// Register this observer via `moinsenRunApp()` to automatically
/// capture lifecycle events (resumed, inactive, paused, detached,
/// hidden). The lifecycle history helps LLMs diagnose bugs caused
/// by background/foreground transitions (e.g. WebSocket disconnects,
/// timer pauses, resource disposal).
class MoinsenLifecycleObserver with WidgetsBindingObserver {
  MoinsenLifecycleObserver._() : _createdAt = DateTime.now();

  static MoinsenLifecycleObserver? _instance;

  /// The shared observer instance.
  // ignore: prefer_constructors_over_static_methods
  static MoinsenLifecycleObserver get instance =>
      _instance ??= MoinsenLifecycleObserver._();

  /// Whether an observer instance has been created.
  static bool get isInstalled => _instance != null;

  /// Reset the singleton (for testing only).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  static const _historyCapacity = 50;

  final DateTime _createdAt;
  final List<LifecycleRecord> _history = [];
  AppLifecycleState _currentState = AppLifecycleState.resumed;

  /// The current app lifecycle state.
  AppLifecycleState get currentState => _currentState;

  /// Unmodifiable view of lifecycle transition history.
  List<LifecycleRecord> get history => List.unmodifiable(_history);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ignore duplicate consecutive states.
    if (state == _currentState) return;

    final previous = _currentState;
    _currentState = state;

    if (_history.length >= _historyCapacity) {
      _history.removeAt(0);
    }
    _history.add(
      LifecycleRecord(
        state: state,
        previousState: previous,
        timestamp: DateTime.now(),
      ),
    );
  }

  /// Serialize current state to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'currentState': _currentState.name,
    'uptime_ms': DateTime.now().difference(_createdAt).inMilliseconds,
    'history': _history.map((r) => r.toJson()).toList(),
  };
}

/// A single lifecycle state transition.
class LifecycleRecord {
  const LifecycleRecord({
    required this.state,
    required this.previousState,
    required this.timestamp,
  });

  /// The new lifecycle state.
  final AppLifecycleState state;

  /// The state before this transition.
  final AppLifecycleState previousState;

  /// When this transition occurred.
  final DateTime timestamp;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'state': state.name,
    'previousState': previousState.name,
    'timestamp': timestamp.toIso8601String(),
  };
}
