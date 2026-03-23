import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Inspect registered app state from the running app.
class InspectCommand extends VmCommand {
  @override
  String get name => 'inspect';

  @override
  String get description =>
      'Inspect registered app state (via moinsenExposeState).';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    // Optional: specific key from positional args.
    final rest = argResults?.rest ?? <String>[];
    final key = rest.isNotEmpty ? rest.first : null;

    final params = <String, String>{};
    if (key != null) params['key'] = key;

    final result = await client.callMoinsenWithParams(
      'ext.moinsen.getState',
      params: params.isNotEmpty ? params : null,
    );

    if (result != null) {
      stdout.writeln(jsonEncode(result));
    } else {
      stdout.writeln(
        jsonEncode({'error': 'Failed to get app state'}),
      );
    }
  }
}
