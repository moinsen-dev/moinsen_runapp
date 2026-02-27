import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Trigger hot restart on the running app.
class RestartCommand extends VmCommand {
  @override
  String get name => 'restart';

  @override
  String get description => 'Trigger hot restart on the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.hotRestart();
    stdout.writeln(jsonEncode(result));
  }
}
