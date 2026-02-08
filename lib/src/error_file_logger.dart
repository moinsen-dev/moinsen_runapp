import 'dart:io';

import 'package:moinsen_runapp/src/error_entry.dart';

/// Optional file logger that writes compressed error summaries to disk.
class ErrorFileLogger {
  ErrorFileLogger({
    required this.filePath,
    this.maxFileSize = 1024 * 1024, // 1 MB
  });

  /// Path to the log file.
  final String filePath;

  /// Maximum file size before rotation (in bytes).
  final int maxFileSize;

  bool _initialized = false;
  IOSink? _sink;

  /// Initialize the file logger. Creates parent directories if needed.
  Future<void> init() async {
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);

      // Rotate if file exceeds max size.
      if (file.existsSync() && file.lengthSync() > maxFileSize) {
        final rotated = File('$filePath.old');
        if (rotated.existsSync()) await rotated.delete();
        await file.rename(rotated.path);
      }

      _sink = File(filePath).openWrite(mode: FileMode.append);
      _initialized = true;
    } on Object catch (_) {
      // File logging is best-effort. Silently degrade.
      _initialized = false;
    }
  }

  /// Write an error entry to the log file.
  void log(ErrorEntry entry) {
    if (!_initialized || _sink == null) return;

    final timestamp = entry.firstSeen.toIso8601String();
    final frames = entry.stackTrace
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(3)
        .join(' | ');

    _sink!.writeln(
      '[$timestamp] [${entry.source}] '
      '${entry.error.runtimeType}: '
      '${_truncate(entry.error.toString(), 200)} '
      '(count: ${entry.count}) $frames',
    );
  }

  /// Log a dedup summary.
  void logSummary(ErrorEntry entry) {
    if (!_initialized || _sink == null || entry.count <= 1) return;

    final timestamp = DateTime.now().toIso8601String();
    final spanSeconds = entry.span.inMilliseconds / 1000;
    _sink!.writeln(
      '[$timestamp] SUMMARY: ${entry.count}× '
      '${_truncate(entry.error.toString(), 80)} '
      '(${spanSeconds.toStringAsFixed(1)}s)',
    );
  }

  /// Flush and close the log file.
  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }

  String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen - 3)}...';
  }
}
