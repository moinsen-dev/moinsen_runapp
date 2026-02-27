import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get recent log entries from the running app.
class LogsCommand extends VmCommand {
  LogsCommand() {
    argParser.addOption(
      'last',
      abbr: 'n',
      help: 'Number of recent log entries to return.',
      defaultsTo: '50',
    );
  }

  @override
  String get name => 'logs';

  @override
  String get description => 'Get recent log entries from the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final lastArg = argResults?['last'] as String? ?? '50';
    final last = int.tryParse(lastArg) ?? 50;
    final result = await client.callMoinsen('ext.moinsen.getLogs');

    if (result != null) {
      // Trim to requested count.
      final logs = result['logs'] as List<dynamic>? ?? <dynamic>[];
      final trimmed = logs.length > last
          ? logs.sublist(logs.length - last)
          : logs;
      stdout.writeln(jsonEncode({
        'logs': trimmed,
        'returned': trimmed.length,
        'total': logs.length,
      }));
    } else {
      stdout.writeln(jsonEncode({
        'logs': <dynamic>[],
        'returned': 0,
        'total': 0,
      }));
    }
  }
}
