import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

/// Generate a comprehensive app context report in markdown format.
///
/// This is the LLM-optimized "tell me everything" output, combining
/// errors, logs, route information, and optional widget tree into a
/// single structured document.
String generateContext({
  required List<ErrorEntry> errors,
  required String platform,
  required List<LogEntry> recentLogs,
  String? currentRoute,
  bool observerInstalled = false,
  List<Map<String, dynamic>>? routeHistory,
  String? widgetTree,
  String? screenshotPath,
}) {
  final buffer = StringBuffer()
    ..writeln('# App Context Report')
    ..writeln()
    ..writeln(
      '**Generated:** '
      '${DateTime.now().toIso8601String().substring(0, 19)}',
    )
    ..write('**Platform:** $platform');

  if (currentRoute != null) {
    buffer.write(' | **Route:** $currentRoute');
  }

  final totalErrors = errors.fold(0, (sum, e) => sum + e.count);
  buffer
    ..write(' | **Errors:** ${errors.length} unique, $totalErrors total')
    ..writeln()
    ..writeln();

  // Errors section
  if (errors.isNotEmpty) {
    buffer
      ..writeln('## Errors')
      ..writeln();
    for (var i = 0; i < errors.length; i++) {
      final e = errors[i];
      buffer.writeln(
        '${i + 1}. **${e.error.runtimeType}** '
        '(${e.count}×, source: ${e.source}): '
        '${_truncate(e.error.toString(), 120)}',
      );
    }
    buffer.writeln();
  }

  // Recent logs section
  if (recentLogs.isNotEmpty) {
    buffer
      ..writeln('## Recent Logs (${recentLogs.length})')
      ..writeln()
      ..writeln('| Time | Level | Source | Message |')
      ..writeln('|------|-------|--------|---------|');
    for (final log in recentLogs) {
      final time = log.timestamp.toIso8601String().substring(11, 19);
      buffer.writeln(
        '| $time | ${log.level} | ${log.source ?? '-'} '
        '| ${_truncate(log.message, 80)} |',
      );
    }
    buffer.writeln();
  }

  // Navigation history section
  if (routeHistory != null && routeHistory.isNotEmpty) {
    buffer
      ..writeln('## Navigation History')
      ..writeln();
    for (final entry in routeHistory) {
      final time = (entry['timestamp'] as String?)?.substring(11, 19) ?? '?';
      buffer.writeln(
        '- $time ${entry['action']} '
        '${entry['routeName'] ?? '(unnamed)'}',
      );
    }
    buffer.writeln();
  } else if (!observerInstalled) {
    buffer
      ..writeln('## Navigation')
      ..writeln()
      ..writeln('_MoinsenNavigatorObserver not installed._')
      ..writeln();
  }

  // Screenshot reference
  if (screenshotPath != null) {
    buffer
      ..writeln('## Screenshot')
      ..writeln()
      ..writeln('Saved to: `$screenshotPath`')
      ..writeln();
  }

  // Widget tree
  if (widgetTree != null) {
    buffer
      ..writeln('## Widget Tree')
      ..writeln()
      ..writeln('```')
      ..writeln(_condenseWidgetTree(widgetTree))
      ..writeln('```')
      ..writeln();
  }

  return buffer.toString();
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 3)}...';
}

/// Condense a widget tree dump to key widgets only.
String _condenseWidgetTree(String tree) {
  // Keep lines containing common important widgets and indentation
  // to give LLMs a structural overview without the full dump.
  final lines = tree.split('\n');
  if (lines.length <= 50) return tree;

  // Take first 50 lines and add a note
  return '${lines.take(50).join('\n')}\n... (${lines.length - 50} more lines)';
}
