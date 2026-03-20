import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get the current route and navigation history from the running app.
class RouteCommand extends VmCommand {
  RouteCommand() {
    argParser.addOption(
      'history',
      abbr: 'n',
      help: 'Number of history entries to return.',
      defaultsTo: '10',
    );
  }

  @override
  String get name => 'route';

  @override
  String get description => 'Get the current route and navigation history.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final historyCount =
        int.tryParse(
          argResults?['history'] as String? ?? '10',
        ) ??
        10;
    final result = await client.callMoinsen('ext.moinsen.getRoute');

    if (result != null) {
      final history = result['history'] as List<dynamic>? ?? <dynamic>[];
      final trimmed = history.length > historyCount
          ? history.sublist(history.length - historyCount)
          : history;
      stdout.writeln(
        jsonEncode({
          'currentRoute': result['currentRoute'],
          'observerInstalled': result['observerInstalled'],
          'history': trimmed,
          'returned': trimmed.length,
          'total': history.length,
        }),
      );
    } else {
      stdout.writeln(
        jsonEncode({
          'currentRoute': null,
          'observerInstalled': false,
          'history': <dynamic>[],
        }),
      );
    }
  }
}
