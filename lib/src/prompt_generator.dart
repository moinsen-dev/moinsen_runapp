import 'package:moinsen_runapp/src/error_entry.dart';

/// Generate a structured markdown bug report from a list of error entries.
///
/// This is the same report format used by the debug screen's "Copy All"
/// button, extracted here so it can also be served via VM Service extensions.
String generateBugReport({
  required List<ErrorEntry> errors,
  required String platform,
}) {
  final totalCount = errors.fold(0, (sum, e) => sum + e.count);
  final buffer = StringBuffer()
    ..writeln('# Bug Report')
    ..writeln()
    ..writeln(
      '**Generated:** '
      '${DateTime.now().toIso8601String().substring(0, 19)}',
    )
    ..writeln('**Platform:** $platform')
    ..writeln(
      '**Errors:** ${errors.length} unique, $totalCount total',
    )
    ..writeln();

  for (var i = 0; i < errors.length; i++) {
    _formatEntry(buffer, errors[i], i, errors.length);
  }

  return buffer.toString();
}

void _formatEntry(
  StringBuffer buffer,
  ErrorEntry entry,
  int index,
  int total,
) {
  final allFrames = entry.stackTrace
      .toString()
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  final appFrames = _filterAppFrames(allFrames);

  buffer
    ..writeln('---')
    ..writeln()
    ..writeln(
      '## Error ${index + 1}/$total: '
      '${entry.error.runtimeType}',
    )
    ..writeln();

  // Location from the first app frame.
  if (appFrames.isNotEmpty) {
    final location = _extractLocation(appFrames.first);
    if (location != null) {
      buffer.writeln('**Location:** `$location`');
    }
  }

  buffer
    ..writeln('**Message:** ${_truncateMessage(entry.error.toString())}')
    ..writeln('**Source:** ${_sourceDescription(entry.source)}')
    ..writeln('**Occurrences:** ${entry.count}');

  // Flutter diagnostics — the richest context available.
  if (entry.diagnostics != null) {
    buffer
      ..writeln()
      ..writeln('### Flutter Diagnostics')
      ..writeln('```')
      ..writeln(_cleanDiagnostics(entry.diagnostics!))
      ..writeln('```');
  }

  // App-specific stack frames.
  if (appFrames.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('### App Stack Trace')
      ..writeln('```');
    for (final frame in appFrames) {
      buffer.writeln(frame.trim());
    }
    buffer.writeln('```');
  }

  // Context trace: framework frames for call-chain context.
  final contextFrames = allFrames
      .where(
        (l) =>
            l.contains('package:flutter/') ||
            l.contains('package:go_router/') ||
            l.contains('package:flutter_riverpod/') ||
            l.contains('package:riverpod/'),
      )
      .take(5)
      .toList();

  if (contextFrames.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln('### Context Trace (framework)')
      ..writeln('```');
    for (final frame in contextFrames) {
      buffer.writeln(frame.trim());
    }
    buffer.writeln('```');
  }

  // Fallback: if no app frames AND no diagnostics, show raw top frames.
  if (appFrames.isEmpty && entry.diagnostics == null) {
    buffer
      ..writeln()
      ..writeln('### Raw Stack Trace (top 15)')
      ..writeln('```');
    for (final frame in allFrames.take(15)) {
      buffer.writeln(frame.trim());
    }
    buffer.writeln('```');
  }

  buffer.writeln();
}

/// Filters stack frames to only app-relevant ones.
List<String> _filterAppFrames(List<String> frames) {
  return frames
      .where((line) {
        if (line.contains('package:flutter/')) return false;
        if (line.contains('dart:')) return false;
        if (line.contains('package:moinsen_runapp/')) return false;
        return true;
      })
      .toList();
}

/// Extracts a human-readable location from a stack frame line.
String? _extractLocation(String frameLine) {
  final match = RegExp(
    r'(\w+(?:\.\w+)*)\s+\(package:\w+/(.+?):(\d+)',
  ).firstMatch(frameLine);
  if (match != null) {
    return '${match.group(2)}:${match.group(3)} — ${match.group(1)}';
  }
  return null;
}

/// Truncates error messages that embed full stack traces.
String _truncateMessage(String message) {
  final lines = message.split('\n');
  final kept = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (RegExp(r'^#\d+\s').hasMatch(trimmed)) break;
    if (trimmed == 'The stack trace of the exception:' ||
        trimmed.startsWith('When the exception was thrown')) {
      break;
    }
    kept.add(line);
  }
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  final result = kept.join('\n');
  if (result.length < message.length) {
    return '$result\n_(stack trace truncated — see sections below)_';
  }
  return result;
}

/// Strips box-drawing decoration and embedded stack traces from diagnostics.
String _cleanDiagnostics(String raw) {
  final lines = raw.split('\n');
  final cleaned = <String>[];
  var skipSection = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('═')) continue;

    if (trimmed.startsWith('When the exception was thrown') ||
        trimmed == 'The stack trace of the exception:') {
      skipSection = true;
      continue;
    }

    if (RegExp(r'^#\d+\s').hasMatch(trimmed)) continue;

    if (skipSection) {
      if (!trimmed.startsWith('#') &&
          !trimmed.startsWith('(') &&
          trimmed.contains(':') &&
          !line.startsWith(' ')) {
        skipSection = false;
      } else {
        continue;
      }
    }

    final clean = line.replaceFirst(RegExp(r'^[│║]\s?'), '');
    cleaned.add(clean);
  }

  return cleaned.join('\n');
}

/// Generate an enhanced report that includes logs and route context
/// alongside errors.
///
/// This extends [generateBugReport] with additional app context
/// for richer LLM-assisted debugging.
String generateEnhancedReport({
  required List<ErrorEntry> errors,
  required String platform,
  List<Map<String, dynamic>> recentLogs = const [],
  String? currentRoute,
  bool observerInstalled = false,
  List<Map<String, dynamic>> routeHistory = const [],
}) {
  final buffer = StringBuffer();

  // Header
  buffer
    ..writeln('# Enhanced Bug Report')
    ..writeln()
    ..writeln(
      '**Generated:** '
      '${DateTime.now().toIso8601String().substring(0, 19)}',
    )
    ..writeln('**Platform:** $platform');

  if (currentRoute != null) {
    buffer.writeln('**Current Route:** $currentRoute');
  }

  final totalCount = errors.fold(0, (sum, e) => sum + e.count);
  buffer
    ..writeln(
      '**Errors:** ${errors.length} unique, $totalCount total',
    )
    ..writeln();

  // Error details (reuse the existing _formatEntry helper)
  for (var i = 0; i < errors.length; i++) {
    _formatEntry(buffer, errors[i], i, errors.length);
  }

  // Recent logs section
  if (recentLogs.isNotEmpty) {
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Recent Logs (${recentLogs.length})')
      ..writeln();
    for (final log in recentLogs) {
      final ts = log['timestamp'] as String? ?? '';
      final time = ts.length >= 19 ? ts.substring(11, 19) : ts;
      final level = log['level'] as String? ?? '?';
      final source = log['source'] as String? ?? '';
      final msg = log['message'] as String? ?? '';
      buffer.writeln(
        '- `[$time]` **$level** '
        '${source.isNotEmpty ? '($source) ' : ''}$msg',
      );
    }
    buffer.writeln();
  }

  // Navigation history
  if (routeHistory.isNotEmpty) {
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Navigation History')
      ..writeln();
    for (final entry in routeHistory) {
      final ts = entry['timestamp'] as String? ?? '';
      final time = ts.length >= 19 ? ts.substring(11, 19) : ts;
      buffer.writeln(
        '- $time ${entry['action']} '
        '${entry['routeName'] ?? '(unnamed)'}',
      );
    }
    buffer.writeln();
  } else if (!observerInstalled) {
    buffer
      ..writeln('---')
      ..writeln()
      ..writeln('## Navigation')
      ..writeln()
      ..writeln('_MoinsenNavigatorObserver not installed._')
      ..writeln();
  }

  return buffer.toString();
}

/// Human-readable description of the error source layer.
String _sourceDescription(String source) {
  return switch (source) {
    'flutter' => 'flutter (widget build/layout/paint phase)',
    'platform' => 'platform (uncaught async error)',
    'zone' => 'zone (uncaught synchronous error)',
    'init' => 'init (app initialization phase)',
    _ => source,
  };
}
