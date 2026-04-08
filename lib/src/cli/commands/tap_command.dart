import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Tap an element in the running app.
class TapCommand extends VmCommand {
  TapCommand() {
    argParser
      ..addOption('key', help: 'ValueKey<String> of the widget')
      ..addOption('text', help: 'Text content of the widget')
      ..addOption('type', help: 'Runtime type name of the widget')
      ..addOption('x', help: 'X coordinate for direct tap')
      ..addOption('y', help: 'Y coordinate for direct tap');
  }

  @override
  String get name => 'tap';

  @override
  String get description => 'Tap an element by key, text, type, or coords.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final params = <String, String>{};
    for (final key in ['key', 'text', 'type', 'x', 'y']) {
      final value = argResults?[key] as String?;
      if (value != null) params[key] = value;
    }

    if (params.isEmpty) {
      stderr.writeln(
        jsonEncode({
          'error': 'Specify --key, --text, --type, or --x/--y',
        }),
      );
      exit(1);
    }

    final result = await client.callMoinsenWithParams(
      'ext.moinsen.tap',
      params: params,
    );
    stdout.writeln(
      jsonEncode(
        result ?? <String, dynamic>{'success': false},
      ),
    );
  }
}
