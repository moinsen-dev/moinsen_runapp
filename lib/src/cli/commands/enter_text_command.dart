import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Enter text into a text field in the running app.
class EnterTextCommand extends VmCommand {
  EnterTextCommand() {
    argParser
      ..addOption('key', help: 'ValueKey<String> of the text field')
      ..addOption('text', help: 'Text content to match the field')
      ..addOption('type', help: 'Runtime type name of the field')
      ..addOption('input', help: 'Text to enter', mandatory: true);
  }

  @override
  String get name => 'enter-text';

  @override
  String get description => 'Enter text into a field by key, text, or type.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final params = <String, String>{};
    for (final key in ['key', 'text', 'type', 'input']) {
      final value = argResults?[key] as String?;
      if (value != null) params[key] = value;
    }

    final result = await client.callMoinsenWithParams(
      'ext.moinsen.enterText',
      params: params,
    );
    stdout.writeln(
      jsonEncode(
        result ?? <String, dynamic>{'success': false},
      ),
    );
  }
}
