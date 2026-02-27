/// A single log entry captured by the [LogBuffer].
class LogEntry {
  LogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.source,
  });

  /// Severity: 'info', 'warning', or 'error'.
  final String level;

  /// The log message text.
  final String message;

  /// When the entry was recorded.
  final DateTime timestamp;

  /// Optional origin identifier (e.g. 'flutter', 'zone').
  final String? source;

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'level': level,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        if (source != null) 'source': source,
      };
}

/// Fixed-capacity ring buffer for log entries.
///
/// Stores the most recent [capacity] entries and silently discards
/// the oldest when full. Thread-safe for single-isolate use.
class LogBuffer {
  LogBuffer({this.capacity = 200});

  /// Maximum entries to retain.
  final int capacity;

  final List<LogEntry> _buffer = [];

  /// Number of entries currently stored.
  int get size => _buffer.length;

  /// All stored entries in chronological order.
  List<LogEntry> get entries => List.unmodifiable(_buffer);

  /// Add a new log entry, evicting the oldest if at capacity.
  void add({
    required String level,
    required String message,
    String? source,
  }) {
    if (_buffer.length >= capacity) {
      _buffer.removeAt(0);
    }
    _buffer.add(
      LogEntry(
        level: level,
        message: message,
        timestamp: DateTime.now(),
        source: source,
      ),
    );
  }

  /// Remove all entries.
  void clear() => _buffer.clear();

  /// Serialize all entries to JSON-compatible list.
  List<Map<String, dynamic>> toJson() =>
      _buffer.map((e) => e.toJson()).toList();
}
