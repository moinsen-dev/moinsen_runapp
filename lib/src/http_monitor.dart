import 'package:flutter/widgets.dart' show visibleForTesting;

/// Monitors HTTP requests and responses in a ring buffer.
///
/// Provides network traffic visibility for LLM-assisted debugging.
/// Sensitive headers (Authorization, Cookie) are automatically
/// redacted before storage.
class MoinsenHttpMonitor {
  MoinsenHttpMonitor._({int capacity = _defaultCapacity})
    : _capacity = capacity;

  static const _defaultCapacity = 100;
  static const _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authorization',
  };

  static MoinsenHttpMonitor? _instance;

  /// The shared monitor instance with default capacity (100).
  // ignore: prefer_constructors_over_static_methods
  static MoinsenHttpMonitor get instance =>
      _instance ??= MoinsenHttpMonitor._();

  /// Create or get instance with custom capacity.
  // ignore: prefer_constructors_over_static_methods
  static MoinsenHttpMonitor instanceWithCapacity(int capacity) =>
      _instance ??= MoinsenHttpMonitor._(capacity: capacity);

  /// Whether a monitor instance has been created.
  static bool get isInstalled => _instance != null;

  /// Reset the singleton (for testing only).
  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  final int _capacity;
  final List<HttpRecord> _requests = [];

  /// Unmodifiable view of recorded requests (newest last).
  List<HttpRecord> get requests => List.unmodifiable(_requests);

  /// Total number of recorded requests.
  int get totalCount => _requests.length;

  /// Number of requests with error status (4xx, 5xx) or connection error.
  int get errorCount => _requests.where((r) => r.isError).length;

  /// Average request duration in milliseconds, or 0 if empty.
  int get avgDurationMs {
    if (_requests.isEmpty) return 0;
    final total = _requests.fold(0, (sum, r) => sum + r.durationMs);
    return total ~/ _requests.length;
  }

  /// Record an HTTP request/response pair.
  ///
  /// Sensitive headers are automatically redacted.
  void record({
    required String method,
    required String url,
    required Duration duration,
    int? statusCode,
    int? requestSize,
    int? responseSize,
    String? error,
    Map<String, String>? requestHeaders,
    Map<String, String>? responseHeaders,
  }) {
    if (_requests.length >= _capacity) {
      _requests.removeAt(0);
    }
    _requests.add(
      HttpRecord(
        method: method,
        url: url,
        statusCode: statusCode,
        durationMs: duration.inMilliseconds,
        timestamp: DateTime.now(),
        requestSize: requestSize,
        responseSize: responseSize,
        error: error,
        requestHeaders: _sanitizeHeaders(requestHeaders),
        responseHeaders: _sanitizeHeaders(responseHeaders),
      ),
    );
  }

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'totalCount': totalCount,
    'errorCount': errorCount,
    'avgDuration_ms': avgDurationMs,
    'requests': _requests.map((r) => r.toJson()).toList(),
  };

  static Map<String, String>? _sanitizeHeaders(Map<String, String>? headers) {
    if (headers == null) return null;
    return headers.map(
      (key, value) => MapEntry(
        key,
        _sensitiveHeaders.contains(key.toLowerCase()) ? '[REDACTED]' : value,
      ),
    );
  }
}

/// A single recorded HTTP request/response.
class HttpRecord {
  const HttpRecord({
    required this.method,
    required this.url,
    required this.durationMs,
    required this.timestamp,
    this.statusCode,
    this.requestSize,
    this.responseSize,
    this.error,
    this.requestHeaders,
    this.responseHeaders,
  });

  final String method;
  final String url;
  final int? statusCode;
  final int durationMs;
  final DateTime timestamp;
  final int? requestSize;
  final int? responseSize;
  final String? error;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;

  /// Whether this request had an error (4xx, 5xx, or connection error).
  bool get isError {
    if (error != null) return true;
    if (statusCode != null && statusCode! >= 400) return true;
    return false;
  }

  /// Serialize to JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'method': method,
    'url': url,
    if (statusCode != null) 'statusCode': statusCode,
    'duration_ms': durationMs,
    'timestamp': timestamp.toIso8601String(),
    if (requestSize != null) 'requestSize': requestSize,
    if (responseSize != null) 'responseSize': responseSize,
    if (error != null) 'error': error,
    if (requestHeaders != null) 'requestHeaders': requestHeaders,
    if (responseHeaders != null) 'responseHeaders': responseHeaders,
  };
}
