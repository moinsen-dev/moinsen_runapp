import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Trigger hot reload on the running app.
class ReloadCommand extends VmCommand {
  @override
  String get name => 'reload';

  @override
  String get description => 'Trigger hot reload on the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.hotReload();
    stdout.writeln(jsonEncode(result));
  }
}
