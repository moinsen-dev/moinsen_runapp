import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Navigate to a route in the running app.
class NavigateCommand extends VmCommand {
  NavigateCommand() {
    argParser.addFlag(
      'pop',
      help: 'Pop the current route instead of pushing.',
    );
  }

  @override
  String get name => 'navigate';

  @override
  String get description => 'Navigate to a route in the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final pop = argResults?['pop'] as bool? ?? false;
    final rest = argResults?.rest ?? <String>[];
    final route = rest.isNotEmpty ? rest.first : null;

    if (!pop && (route == null || route.isEmpty)) {
      stdout.writeln(
        jsonEncode({
          'navigated': false,
          'error': 'Usage: moinsen_run navigate <route> or --pop',
        }),
      );
      return;
    }

    final params = <String, String>{
      // Null-aware element (if?) requires Dart 3.8+; keep explicit check
      // for backward compatibility.
      // ignore: use_null_aware_elements
      if (route != null) 'route': route,
      if (pop) 'pop': 'true',
    };

    final result = await client.callMoinsenWithParams(
      'ext.moinsen.navigate',
      params: params,
    );

    stdout.writeln(
      jsonEncode(
        result ?? {'navigated': false, 'error': 'No response from app'},
      ),
    );
  }
}
