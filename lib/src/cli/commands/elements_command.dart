import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get interactive elements currently on screen.
class ElementsCommand extends VmCommand {
  @override
  String get name => 'elements';

  @override
  String get description =>
      'Get interactive elements from the running app screen.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.callMoinsen(
      'ext.moinsen.getInteractiveElements',
    );
    stdout.writeln(
      jsonEncode(
        result ??
            <String, dynamic>{
              'elements': <dynamic>[],
              'count': 0,
            },
      ),
    );
  }
}
