import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get the LLM-ready markdown bug report from the running app.
class PromptCommand extends VmCommand {
  @override
  String get name => 'prompt';

  @override
  String get description => 'Get the markdown bug report (LLM-ready prompt).';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final result = await client.callMoinsen('ext.moinsen.getPrompt');
    if (result != null && result['prompt'] != null) {
      // Output the raw markdown, not JSON — for direct LLM consumption.
      stdout.writeln(result['prompt']);
    } else {
      stdout.writeln(jsonEncode({'error': 'No prompt data available'}));
    }
  }
}
