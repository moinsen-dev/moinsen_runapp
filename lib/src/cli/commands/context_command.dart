import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get a comprehensive app context report (LLM-ready).
class ContextCommand extends VmCommand {
  ContextCommand() {
    argParser
      ..addFlag(
        'with-screenshot',
        help: 'Include a screenshot (saved to file).',
      )
      ..addFlag(
        'with-tree',
        help: 'Include the widget tree dump.',
      )
      ..addOption(
        'log-count',
        abbr: 'n',
        help: 'Number of recent log entries to include.',
        defaultsTo: '20',
      )
      ..addOption(
        'screenshot-path',
        help: 'Path for the screenshot file.',
        defaultsTo: './context-screenshot.png',
      )
      ..addOption(
        'format',
        help: 'Output format.',
        defaultsTo: 'markdown',
        allowed: ['markdown', 'json'],
      );
  }

  @override
  String get name => 'context';

  @override
  String get description =>
      'Get a comprehensive app context report (LLM-ready).';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final withScreenshot = argResults?['with-screenshot'] as bool? ?? false;
    final withTree = argResults?['with-tree'] as bool? ?? false;
    final logCount =
        int.tryParse(
          argResults?['log-count'] as String? ?? '20',
        ) ??
        20;
    final screenshotPath =
        argResults?['screenshot-path'] as String? ?? './context-screenshot.png';
    final format = argResults?['format'] as String? ?? 'markdown';

    // Gather data from VM extensions sequentially.
    // Parallel calls can cause issues with the VM Service protocol.
    final errorsData = await client.callMoinsen('ext.moinsen.getErrors');
    final logsData = await client.callMoinsen('ext.moinsen.getLogs');
    final routeData = await client.callMoinsen('ext.moinsen.getRoute');
    final infoData = await client.callMoinsen('ext.moinsen.getInfo');

    // Optional: screenshot
    String? savedScreenshotPath;
    if (withScreenshot) {
      final screenshotResult = await client.callMoinsenWithParams(
        'ext.moinsen.screenshot',
      );
      if (screenshotResult != null && screenshotResult['screenshot'] != null) {
        final bytes = base64Decode(
          screenshotResult['screenshot'] as String,
        );
        final file = File(screenshotPath);
        await file.writeAsBytes(bytes);
        savedScreenshotPath = file.absolute.path;
      }
    }

    // Optional: widget tree
    String? widgetTree;
    if (withTree) {
      widgetTree = await client.getWidgetTree();
    }

    if (format == 'json') {
      // JSON format: raw data
      stdout.writeln(
        jsonEncode({
          'errors': errorsData,
          'logs': logsData,
          'route': routeData,
          'info': infoData,
          'screenshotPath': ?savedScreenshotPath,
          'widgetTree': ?widgetTree,
        }),
      );
      return;
    }

    // Markdown format: generate context report.
    // Parse the gathered data for the context generator.
    final errors = errorsData?['errors'] as List<dynamic>? ?? <dynamic>[];
    final allLogs = logsData?['logs'] as List<dynamic>? ?? <dynamic>[];
    final recentLogs = allLogs.length > logCount
        ? allLogs.sublist(allLogs.length - logCount)
        : allLogs;
    final platform = infoData?['platform'] as String? ?? 'unknown';
    final currentRoute = routeData?['currentRoute'] as String?;
    final observerInstalled = routeData?['observerInstalled'] as bool? ?? false;
    final routeHistory = (routeData?['history'] as List<dynamic>?)
        ?.cast<Map<String, dynamic>>();
    final totalErrorCount = errorsData?['totalCount'] as int? ?? 0;
    final uniqueErrorCount = errorsData?['uniqueCount'] as int? ?? 0;

    // Build markdown manually since we don't have ErrorEntry objects
    // on the CLI side (only JSON maps).
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
    buffer
      ..write(
        ' | **Errors:** $uniqueErrorCount unique, '
        '$totalErrorCount total',
      )
      ..writeln()
      ..writeln();

    // Errors
    if (errors.isNotEmpty) {
      buffer
        ..writeln('## Errors')
        ..writeln();
      for (var i = 0; i < errors.length; i++) {
        final e = errors[i] as Map<String, dynamic>;
        final count = e['count'] as int? ?? 1;
        final source = e['source'] as String? ?? '?';
        final errorType = e['errorType'] as String? ?? 'Unknown';
        final message = e['message'] as String? ?? '';
        final truncMsg = message.length > 120
            ? '${message.substring(0, 117)}...'
            : message;
        buffer.writeln(
          '${i + 1}. **$errorType** '
          '($count×, source: $source): $truncMsg',
        );
      }
      buffer.writeln();
    }

    // Logs
    if (recentLogs.isNotEmpty) {
      buffer
        ..writeln('## Recent Logs (${recentLogs.length})')
        ..writeln()
        ..writeln('| Time | Level | Source | Message |')
        ..writeln('|------|-------|--------|---------|');
      for (final log in recentLogs) {
        final logMap = log as Map<String, dynamic>;
        final ts = logMap['timestamp'] as String? ?? '';
        final time = ts.length >= 19 ? ts.substring(11, 19) : ts;
        final level = logMap['level'] as String? ?? '?';
        final source = logMap['source'] as String? ?? '-';
        final msg = logMap['message'] as String? ?? '';
        final truncMsg = msg.length > 80 ? '${msg.substring(0, 77)}...' : msg;
        buffer.writeln('| $time | $level | $source | $truncMsg |');
      }
      buffer.writeln();
    }

    // Navigation
    if (routeHistory != null && routeHistory.isNotEmpty) {
      buffer
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
        ..writeln('## Navigation')
        ..writeln()
        ..writeln('_MoinsenNavigatorObserver not installed._')
        ..writeln();
    }

    // Screenshot
    if (savedScreenshotPath != null) {
      buffer
        ..writeln('## Screenshot')
        ..writeln()
        ..writeln('Saved to: `$savedScreenshotPath`')
        ..writeln();
    }

    // Widget tree
    if (widgetTree != null) {
      final lines = widgetTree.split('\n');
      final condensed = lines.length <= 50
          ? widgetTree
          : '${lines.take(50).join('\n')}\n'
                '... (${lines.length - 50} more lines)';
      buffer
        ..writeln('## Widget Tree')
        ..writeln()
        ..writeln('```')
        ..writeln(condensed)
        ..writeln('```')
        ..writeln();
    }

    stdout.write(buffer);
  }
}
