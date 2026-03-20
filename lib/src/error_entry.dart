/// A deduplicated error entry tracked by the error bucket.
class ErrorEntry {
  ErrorEntry({
    required this.hash,
    required this.error,
    required this.stackTrace,
    required this.source,
    required this.firstSeen,
    this.diagnostics,
    DateTime? lastSeen,
    this.count = 1,
  }) : lastSeen = lastSeen ?? firstSeen;

  /// Unique hash derived from error type, message, and top stack frames.
  final String hash;

  /// The original error object.
  final Object error;

  /// Stack trace captured at the error site.
  final StackTrace stackTrace;

  /// Where the error was caught: 'flutter', 'platform', 'zone', or 'init'.
  final String source;

  /// Rich diagnostic context when available.
  ///
  /// For flutter-source errors this contains the full
  /// `FlutterErrorDetails.toString()` output including the widget
  /// context, library, and formatted diagnostics.
  final String? diagnostics;

  /// When this error was first seen.
  final DateTime firstSeen;

  /// When this error was last seen (updated on duplicates).
  DateTime lastSeen;

  /// How many times this exact error has occurred.
  int count;

  /// Short human-readable label for the error.
  String get label {
    final msg = error.toString();
    // Truncate long messages for display.
    if (msg.length > 120) return '${msg.substring(0, 117)}...';
    return msg;
  }

  /// Duration between first and last occurrence.
  Duration get span => lastSeen.difference(firstSeen);

  /// Serialize to a JSON-compatible map for VM Service extensions.
  Map<String, dynamic> toJson() => {
    'hash': hash,
    'errorType': error.runtimeType.toString(),
    'message': error.toString(),
    'stackTrace': stackTrace.toString(),
    'source': source,
    if (diagnostics != null) 'diagnostics': diagnostics,
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
    'count': count,
    'label': label,
  };
}
