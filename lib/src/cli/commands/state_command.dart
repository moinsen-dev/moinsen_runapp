import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Get the widget tree dump from the running app.
class StateCommand extends VmCommand {
  @override
  String get name => 'state';

  @override
  String get description => 'Get the widget tree dump from the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final tree = await client.getWidgetTree();
    stdout.writeln(
      jsonEncode({
        'widgetTree': tree ?? 'Unable to retrieve widget tree.',
      }),
    );
  }
}
