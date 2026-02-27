import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';

/// Run `flutter analyze` and return structured JSON output.
class AnalyzeCommand extends Command<void> {
  @override
  String get name => 'analyze';

  @override
  String get description =>
      'Run flutter analyze and return structured results.';

  @override
  Future<void> run() async {
    final result = await Process.run(
      'flutter',
      ['analyze', '--no-fatal-infos', '--no-fatal-warnings'],
    );

    final issues = _parseAnalyzeOutput(result.stdout as String);
    stdout.writeln(jsonEncode({
      'exitCode': result.exitCode,
      'issueCount': issues.length,
      'issues': issues,
    }));
  }

  /// Parse flutter analyze output into structured issues.
  List<Map<String, dynamic>> _parseAnalyzeOutput(String output) {
    final issues = <Map<String, dynamic>>[];
    final lines = output.split('\n');

    for (final line in lines) {
      // Format: "  info • Message • path/to/file.dart:line:col • rule_name"
      // or:     "  error • Message • path/to/file.dart:line:col • rule_name"
      final match = RegExp(
        r'\s*(info|warning|error)\s+[•-]\s+(.+?)\s+[•-]\s+(.+?):(\d+):(\d+)\s+[•-]\s+(\S+)',
      ).firstMatch(line);
      if (match != null) {
        issues.add({
          'severity': match.group(1),
          'message': match.group(2)!.trim(),
          'file': match.group(3),
          'line': int.parse(match.group(4)!),
          'column': int.parse(match.group(5)!),
          'rule': match.group(6),
        });
      }
    }

    return issues;
  }
}
