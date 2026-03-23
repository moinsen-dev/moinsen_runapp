import 'package:flutter/widgets.dart' show visibleForTesting;

/// Opt-in registry for exposing app state to LLM debugging tools.
///
/// App developers register snapshot functions that are called lazily
/// when an LLM queries state. This avoids hard dependencies on any
/// specific state management library (Bloc, Riverpod, Provider, etc.).
///
/// ```dart
/// // In your app initialization:
/// moinsenExposeState('cart', () => cartBloc.state.toJson());
/// moinsenExposeState('user', () => userRepo.currentUser?.toJson());
/// ```
class MoinsenStateRegistry {
  MoinsenStateRegistry._();

  static MoinsenStateRegistry? _instance;

  /// The shared registry instance.
  // ignore: prefer_constructors_over_static_methods
  static MoinsenStateRegistry get instance =>
      _instance ??= MoinsenStateRegistry._();

  /// Whether a registry instance has been created.
  static bool get isInstalled => _instance != null;

  /// Reset the singleton (for testing only).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final Map<String, dynamic Function()> _providers = {};

  /// The set of registered state keys.
  Iterable<String> get keys => _providers.keys;

  /// Register a state snapshot function under [key].
  ///
  /// The function is called lazily only when state is queried.
  /// If [key] is already registered, the old function is replaced.
  void register(String key, dynamic Function() snapshotFn) {
    _providers[key] = snapshotFn;
  }

  /// Remove a state registration.
  void unregister(String key) {
    _providers.remove(key);
  }

  /// Take a snapshot of all registered states.
  ///
  /// If a snapshot function throws, the error message is captured
  /// as the value instead of propagating the exception.
  Map<String, dynamic> snapshot() {
    final result = <String, dynamic>{};
    for (final entry in _providers.entries) {
      try {
        result[entry.key] = entry.value();
      } on Object catch (e) {
        result[entry.key] = 'Error: $e';
      }
    }
    return result;
  }

  /// Take a snapshot of a single key, or `null` if not registered.
  dynamic snapshotKey(String key) {
    final fn = _providers[key];
    if (fn == null) return null;
    try {
      return fn();
    } on Object catch (e) {
      return 'Error: $e';
    }
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'registeredKeys': keys.toList(),
    'states': snapshot(),
  };
}
