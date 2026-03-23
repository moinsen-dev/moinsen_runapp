import 'dart:convert';

import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

/// Generate a comprehensive app context report in markdown format.
///
/// This is the LLM-optimized "tell me everything" output, combining
/// errors, logs, route information, device context, lifecycle state,
/// network traffic, app state, and optional widget tree into a
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
  Map<String, dynamic>? deviceInfo,
  String? lifecycleState,
  List<Map<String, dynamic>>? lifecycleHistory,
  List<Map<String, dynamic>>? networkRequests,
  int? networkErrorCount,
  Map<String, dynamic>? appStates,
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

  // Device & Environment section
  if (deviceInfo != null && deviceInfo.isNotEmpty) {
    buffer
      ..writeln('## Device & Environment')
      ..writeln()
      ..writeln('```json')
      ..writeln(
        const JsonEncoder.withIndent('  ').convert(deviceInfo),
      )
      ..writeln('```')
      ..writeln();
  }

  // Lifecycle section
  if (lifecycleState != null) {
    buffer
      ..writeln('## Lifecycle')
      ..writeln()
      ..writeln('**Current:** $lifecycleState');
    if (lifecycleHistory != null && lifecycleHistory.isNotEmpty) {
      buffer.writeln();
      for (final entry in lifecycleHistory) {
        final ts = entry['timestamp'] as String? ?? '';
        final time = ts.length >= 19 ? ts.substring(11, 19) : ts;
        buffer.writeln(
          '- $time '
          '${entry['previousState']} → ${entry['state']}',
        );
      }
    }
    buffer.writeln();
  }

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

  // Network traffic section
  if (networkRequests != null && networkRequests.isNotEmpty) {
    final errCount = networkErrorCount ?? 0;
    buffer
      ..writeln(
        '## Network Traffic '
        '(${networkRequests.length} requests, $errCount errors)',
      )
      ..writeln()
      ..writeln('| Time | Method | URL | Status | Duration |')
      ..writeln('|------|--------|-----|--------|----------|');
    for (final req in networkRequests) {
      final ts = req['timestamp'] as String? ?? '';
      final time = ts.length >= 19 ? ts.substring(11, 19) : ts;
      final status = req['statusCode']?.toString() ?? 'ERR';
      final url = _truncate(req['url'] as String? ?? '', 50);
      buffer.writeln(
        '| $time | ${req['method']} | $url '
        '| $status | ${req['duration_ms']}ms |',
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

  // App state section
  if (appStates != null && appStates.isNotEmpty) {
    buffer
      ..writeln('## App State')
      ..writeln()
      ..writeln('```json')
      ..writeln(
        const JsonEncoder.withIndent('  ').convert(appStates),
      )
      ..writeln('```')
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

  // Available actions
  buffer
    ..writeln('## Available Actions')
    ..writeln()
    ..writeln('- `ext.moinsen.navigate` — push/pop routes')
    ..writeln('- `hot reload` / `hot restart` — apply code changes')
    ..writeln('- `ext.moinsen.screenshot` — capture current screen')
    ..writeln('- `ext.moinsen.clearErrors` — reset error state')
    ..writeln('- `ext.moinsen.getState` — query registered app state')
    ..writeln();

  return buffer.toString();
}

String _truncate(String s, int maxLen) {
  if (s.length <= maxLen) return s;
  return '${s.substring(0, maxLen - 3)}...';
}

/// Condense a widget tree dump to key widgets only.
String _condenseWidgetTree(String tree) {
  final lines = tree.split('\n');
  if (lines.length <= 50) return tree;

  return '${lines.take(50).join('\n')}\n'
      '... (${lines.length - 50} more lines)';
}
