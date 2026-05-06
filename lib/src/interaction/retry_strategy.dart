import 'dart:async';

/// Retry an interaction call (tap, enterText, scrollTo) with exponential
/// backoff. Designed for the race-condition class: widget tree is mid-rebuild
/// after navigation or hot-restart, the matcher misses on the first attempt,
/// then resolves a few hundred ms later.
///
/// [op] is invoked at most [maxAttempts] times. It must return a result
/// shaped `{success: bool, error?: String, ...}`. We retry only when
/// `success == false` *and* the error matches a no-element-found pattern;
/// other errors propagate immediately.
///
/// Total wall-clock cap ≈ 200 + 400 + 800 = 1.4 s for 3 attempts. Tune via
/// [baseDelay] and [backoffFactor] if a project needs different timing.
Future<Map<String, dynamic>> retryWithBackoff(
  Future<Map<String, dynamic>?> Function() op, {
  int maxAttempts = 3,
  Duration baseDelay = const Duration(milliseconds: 200),
  double backoffFactor = 2.0,
}) async {
  Map<String, dynamic>? lastResult;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    final result = await op();
    lastResult = result;

    final success = result?['success'] as bool? ?? false;
    if (success) {
      return {
        ...result!,
        if (attempt > 1) 'attempts': attempt,
      };
    }

    if (!_isRetriable(result?['error'])) {
      return result ?? {'success': false, 'error': 'No response from app'};
    }

    if (attempt == maxAttempts) break;

    final delayMs = baseDelay.inMilliseconds *
        _intPow(backoffFactor, attempt - 1).round();
    await Future<void>.delayed(Duration(milliseconds: delayMs));
  }
  return {
    ...?lastResult,
    'success': false,
    'attempts': maxAttempts,
    'error':
        '${lastResult?['error'] ?? 'unknown'} '
            '(gave up after $maxAttempts attempts)',
  };
}

/// Errors worth retrying — typically transient widget-tree-not-ready
/// situations after hot-restart or PageRoute settling.
bool _isRetriable(Object? error) {
  if (error == null) return false;
  final msg = error.toString().toLowerCase();
  return msg.contains('no element found') ||
      msg.contains('keymatcher') ||
      msg.contains('textmatcher') ||
      msg.contains('typestringmatcher') ||
      msg.contains('not yet built') ||
      msg.contains('not visible');
}

double _intPow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
