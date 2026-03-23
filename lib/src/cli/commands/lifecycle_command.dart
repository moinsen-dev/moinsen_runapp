import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get app lifecycle state and transition history from the running app.
class LifecycleCommand extends VmCommand {
  @override
  String get name => 'lifecycle';

  @override
  String get description => 'Get app lifecycle state and transition history.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.callMoinsen('ext.moinsen.getLifecycle');

    if (result != null) {
      stdout.writeln(jsonEncode(result));
    } else {
      stdout.writeln(
        jsonEncode({'error': 'Failed to get lifecycle state'}),
      );
    }
  }
}
