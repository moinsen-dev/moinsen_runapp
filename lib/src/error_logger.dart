import 'dart:developer' as developer;

import 'package:moinsen_runapp/src/error_entry.dart';

/// Smart console logger that compresses error output.
///
/// - First N unique errors: full output with abbreviated stack trace
/// - After burst threshold: one-line summary per error
/// - Duplicate errors: completely suppressed
class ErrorLogger {
  ErrorLogger({this.burstThreshold = 5});

  /// After this many unique errors are logged within [_burstWindow],
  /// further errors switch to one-line summary mode.
  final int burstThreshold;

  static const _burstWindow = Duration(seconds: 3);

  final Set<String> _loggedHashes = {};

  // Burst tracking.
  DateTime? _burstStart;
  int _burstCount = 0;

  /// Log an error entry. Returns true if this was a new (first) occurrence.
  bool log(ErrorEntry entry) {
    if (_loggedHashes.contains(entry.hash)) {
      // Duplicate within dedup window — suppress console output.
      return false;
    }

    _loggedHashes.add(entry.hash);
    _trackBurst();

    if (_burstCount > burstThreshold) {
      // Over threshold — compressed one-line output.
      _logCompressed(entry);
    } else {
      // Under threshold — full details.
      _logFull(entry);
    }

    return true;
  }

  /// Log a dedup summary when the window closes and count > 1.
  void logSummary(ErrorEntry entry) {
    if (entry.count <= 1) return;

    final spanSeconds = entry.span.inMilliseconds / 1000;
    developer.log(
      '┌ ${entry.count}× '
      '${_truncate(entry.error.toString(), 80)} '
      '(${spanSeconds.toStringAsFixed(1)}s)',
      name: 'moinsen_runapp',
    );
  }

  /// Reset logged hashes (e.g., on clear).
  void reset() {
    _loggedHashes.clear();
    _burstCount = 0;
    _burstStart = null;
  }

  void _trackBurst() {
    final now = DateTime.now();
    if (_burstStart == null || now.difference(_burstStart!) > _burstWindow) {
      _burstStart = now;
      _burstCount = 1;
    } else {
      _burstCount++;
    }
  }

  void _logFull(ErrorEntry entry) {
    final buffer = StringBuffer()
      ..writeln(
        '┌─ moinsen_runapp '
        '─────────────────────────────',
      )
      ..writeln(
        '│ ${entry.error.runtimeType}: '
        '${_truncate(entry.error.toString(), 200)}',
      )
      ..writeln('│ source: ${entry.source}')
      ..writeln(
        '│ time: ${entry.firstSeen.toIso8601String()}',
      );

    // Abbreviated stack: top 5 meaningful frames.
    final frames = entry.stackTrace
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(5);
    for (final frame in frames) {
      buffer.writeln('│   $frame');
    }
    buffer.write(
      '└─────────────────────────────'
      '────────────────',
    );

    developer.log(
      buffer.toString(),
      name: 'moinsen_runapp',
      error: entry.error,
      stackTrace: entry.stackTrace,
    );
  }

  void _logCompressed(ErrorEntry entry) {
    // First time hitting the threshold — emit a notice.
    if (_burstCount == burstThreshold + 1) {
      developer.log(
        '│ ... burst detected, switching to '
        'compressed output',
        name: 'moinsen_runapp',
      );
    }

    final topFrame = entry.stackTrace
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(1)
        .join();

    developer.log(
      '│ [${entry.source}] '
      '${entry.error.runtimeType}: '
      '${_truncate(entry.error.toString(), 80)} '
      '@ $topFrame',
      name: 'moinsen_runapp',
    );
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen - 3)}...';
  }
}
