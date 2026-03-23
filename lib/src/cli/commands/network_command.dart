import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get HTTP/network traffic from the running app.
class NetworkCommand extends VmCommand {
  NetworkCommand() {
    argParser
      ..addFlag(
        'errors',
        help: 'Show only failed requests (4xx, 5xx, errors).',
      )
      ..addOption(
        'last',
        abbr: 'n',
        help: 'Number of recent requests to return.',
        defaultsTo: '50',
      );
  }

  @override
  String get name => 'network';

  @override
  String get description => 'Get HTTP/network traffic from the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final errorsOnly = argResults?['errors'] as bool? ?? false;
    final last = int.tryParse(argResults?['last'] as String? ?? '50') ?? 50;

    final result = await client.callMoinsen('ext.moinsen.getNetwork');

    if (result != null) {
      var requests = result['requests'] as List<dynamic>? ?? <dynamic>[];

      if (errorsOnly) {
        requests = requests.where((r) {
          final req = r as Map<String, dynamic>;
          final status = req['statusCode'] as int?;
          final error = req['error'] as String?;
          return error != null || (status != null && status >= 400);
        }).toList();
      }

      if (requests.length > last) {
        requests = requests.sublist(requests.length - last);
      }

      stdout.writeln(
        jsonEncode({
          'totalCount': result['totalCount'],
          'errorCount': result['errorCount'],
          'avgDuration_ms': result['avgDuration_ms'],
          'requests': requests,
          'returned': requests.length,
        }),
      );
    } else {
      stdout.writeln(
        jsonEncode({
          'error': 'Failed to get network traffic',
        }),
      );
    }
  }
}
