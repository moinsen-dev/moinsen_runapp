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
    final statePath = '${Directory.current.path}/.moinsen_run.json';
    final state = readStateFile(path: statePath);

    if (state == null) {
      stderr.writeln(
        jsonEncode({
          'error': 'No running app found. Start one with: moinsen_run start',
        }),
      );
      exit(1);
    }

    // Stale-state guard: if the recorded PID is no longer alive (the user
    // killed flutter run externally, the process crashed, etc.), the state
    // file is lying. Clean it up and surface a clear error instead of a
    // generic "Failed to connect to VM Service" further down.
    if (!_isProcessAlive(state.pid)) {
      deleteStateFile(path: statePath);
      stderr.writeln(
        jsonEncode({
          'error':
              'App not running (PID ${state.pid} is dead). State file '
                  'cleaned up. Run `moinsen_run start` to launch fresh.',
          'staleStatePath': statePath,
        }),
      );
      exit(1);
    }

    MoinsenVmClient? client;
    try {
      client = await MoinsenVmClient.connect(state.vmServiceUri);
      await execute(client);
    } on Object catch (e) {
      stderr.writeln(
        jsonEncode({
          'error': 'Failed to connect to VM Service: $e',
          'vmServiceUri': state.vmServiceUri,
        }),
      );
      exit(1);
    } finally {
      await client?.dispose();
    }
  }

  /// POSIX `kill -0 <pid>` — presence check that doesn't actually signal.
  /// On Windows we fall back to `tasklist`. Errors mean "assume alive" so
  /// we don't accidentally clobber a healthy session over a probe failure.
  bool _isProcessAlive(int pid) {
    try {
      if (Platform.isWindows) {
        final result = Process.runSync(
          'tasklist',
          ['/FI', 'PID eq $pid', '/NH'],
        );
        return result.exitCode == 0 &&
            (result.stdout as String).contains('$pid');
      }
      final result = Process.runSync('kill', ['-0', '$pid']);
      return result.exitCode == 0;
    } on Object {
      return true;
    }
  }

  /// Implement this to execute the command with an active VM Service client.
  Future<void> execute(MoinsenVmClient client);
}
