import 'package:moinsen_runapp/src/error_entry.dart';

/// Deduplication engine that prevents "1000 identical errors in 3 seconds".
///
/// Hashes each error by (runtimeType, message, top 3 stack frames) and
/// maintains a map of unique errors with occurrence counts.
class ErrorBucket {
  ErrorBucket({
    this.deduplicationWindow = const Duration(seconds: 2),
    this.maxEntries = 50,
  });

  /// Time window for considering errors as duplicates.
  final Duration deduplicationWindow;

  /// Maximum unique error entries to retain.
  final int maxEntries;

  final Map<String, ErrorEntry> _entries = {};

  bool _paused = false;

  /// Whether the bucket is paused (ignoring new errors).
  bool get isPaused => _paused;

  /// Pause error capture. New errors are silently dropped.
  void pause() => _paused = true;

  /// Resume error capture.
  void resume() => _paused = false;

  /// All tracked error entries, ordered by first occurrence.
  List<ErrorEntry> get entries {
    final sorted = _entries.values.toList()
      ..sort(
        (a, b) => a.firstSeen.compareTo(b.firstSeen),
      );
    return List.unmodifiable(sorted);
  }

  /// Total number of error occurrences (sum of all counts).
  int get totalCount => _entries.values.fold(0, (sum, e) => sum + e.count);

  /// Number of unique errors tracked.
  int get uniqueCount => _entries.length;

  /// Add an error to the bucket. Returns the entry, or `null` if paused.
  ///
  /// If a matching error exists within the dedup window, the existing
  /// entry's count is incremented. Otherwise a new entry is created.
  /// When [isPaused], new errors are silently dropped.
  ErrorEntry? add({
    required Object error,
    required StackTrace stackTrace,
    required String source,
    String? diagnostics,
  }) {
    if (_paused) return null;

    final hash = _computeHash(error, stackTrace);
    final now = DateTime.now();

    final existing = _entries[hash];
    if (existing != null) {
      final elapsed = now.difference(existing.lastSeen);
      if (elapsed <= deduplicationWindow) {
        existing.count++;
        existing.lastSeen = now;
        return existing;
      }
    }

    // Evict oldest if at capacity.
    if (_entries.length >= maxEntries && !_entries.containsKey(hash)) {
      _evictOldest();
    }

    final entry = ErrorEntry(
      hash: hash,
      error: error,
      stackTrace: stackTrace,
      source: source,
      diagnostics: diagnostics,
      firstSeen: now,
    );
    _entries[hash] = entry;
    return entry;
  }

  /// Remove all entries.
  void clear() => _entries.clear();

  /// Compute a stable hash from error type, message, and top stack frames.
  String _computeHash(Object error, StackTrace stackTrace) {
    final type = error.runtimeType.toString();
    final message = error.toString();

    // Extract top 3 meaningful stack frames.
    final frames = stackTrace
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(3)
        .join('|');

    final input = '$type::$message::$frames';
    // Use a simple string hash instead of pulling in crypto.
    return _simpleHash(input);
  }

  /// Simple deterministic hash that returns a hex string.
  ///
  /// Uses a basic multiplicative hash. Not cryptographic,
  /// just needs to be deterministic for dedup purposes.
  String _simpleHash(String input) {
    var hash = 0x811c9dc5;
    for (var i = 0; i < input.length; i++) {
      hash ^= input.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  void _evictOldest() {
    if (_entries.isEmpty) return;
    String? oldestKey;
    DateTime? oldestTime;
    for (final entry in _entries.entries) {
      if (oldestTime == null || entry.value.firstSeen.isBefore(oldestTime)) {
        oldestKey = entry.key;
        oldestTime = entry.value.firstSeen;
      }
    }
    if (oldestKey != null) _entries.remove(oldestKey);
  }
}
