import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get current errors from the running app.
class ErrorsCommand extends VmCommand {
  @override
  String get name => 'errors';

  @override
  String get description => 'Get the error report from the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.callMoinsen('ext.moinsen.getErrors');
    stdout.writeln(jsonEncode(
      result ?? <String, dynamic>{'errors': <dynamic>[], 'totalCount': 0},
    ));
  }
}
