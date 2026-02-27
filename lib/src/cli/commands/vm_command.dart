import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Base class for commands that connect to a running app via VM Service.
abstract class VmCommand extends Command<void> {
  /// Read state file, connect to VM Service, run the command, disconnect.
  @override
  Future<void> run() async {
    final state = readStateFile(
      path: '${Directory.current.path}/.moinsen_run.json',
    );

    if (state == null) {
      stderr.writeln(jsonEncode({
        'error': 'No running app found. Start one with: moinsen_run start',
      }));
      exit(1);
    }

    MoinsenVmClient? client;
    try {
      client = await MoinsenVmClient.connect(state.vmServiceUri);
      await execute(client);
    } on Object catch (e) {
      stderr.writeln(jsonEncode({
        'error': 'Failed to connect to VM Service: $e',
        'vmServiceUri': state.vmServiceUri,
      }));
      exit(1);
    } finally {
      await client?.dispose();
    }
  }

  /// Implement this to execute the command with an active VM Service client.
  Future<void> execute(MoinsenVmClient client);
}
