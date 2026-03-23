import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get device and environment information from the running app.
class DeviceCommand extends VmCommand {
  @override
  String get name => 'device';

  @override
  String get description => 'Get device and environment information.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.callMoinsen('ext.moinsen.getDeviceInfo');

    if (result != null) {
      stdout.writeln(jsonEncode(result));
    } else {
      stdout.writeln(jsonEncode({'error': 'Failed to get device info'}));
    }
  }
}
