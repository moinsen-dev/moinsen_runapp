import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';

/// Stop the running Flutter app.
class StopCommand extends Command<void> {
  @override
  String get name => 'stop';

  @override
  String get description => 'Stop the running Flutter app.';

  @override
  Future<void> run() async {
    final statePath = '${Directory.current.path}/.moinsen_run.json';
    final state = readStateFile(path: statePath);

    if (state == null) {
      stdout.writeln(
        jsonEncode({
          'stopped': false,
          'error': 'No running app found.',
        }),
      );
      return;
    }

    try {
      Process.killPid(state.pid);
      deleteStateFile(path: statePath);
      stdout.writeln(
        jsonEncode({
          'stopped': true,
          'pid': state.pid,
        }),
      );
    } on Object catch (e) {
      stdout.writeln(
        jsonEncode({
          'stopped': false,
          'error': 'Failed to kill process ${state.pid}: $e',
        }),
      );
    }
  }
}
