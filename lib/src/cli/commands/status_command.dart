import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';

/// Check if the app is running and show connection details.
class StatusCommand extends Command<void> {
  @override
  String get name => 'status';

  @override
  String get description => 'Show whether the app is running and its details.';

  @override
  Future<void> run() async {
    final state = readStateFile(
      path: '${Directory.current.path}/.moinsen_run.json',
    );

    if (state == null) {
      stdout.writeln(jsonEncode({
        'running': false,
      }));
      return;
    }

    // Check if the process is still alive.
    final alive = _isProcessAlive(state.pid);
    if (!alive) {
      deleteStateFile(
        path: '${Directory.current.path}/.moinsen_run.json',
      );
      stdout.writeln(jsonEncode({
        'running': false,
        'stale': true,
        'message': 'State file found but process ${state.pid} is not running.',
      }));
      return;
    }

    final uptime = DateTime.now().difference(state.startedAt);
    stdout.writeln(jsonEncode({
      'running': true,
      'pid': state.pid,
      'device': state.device,
      'vmServiceUri': state.vmServiceUri,
      'startedAt': state.startedAt.toIso8601String(),
      'uptime': _formatDuration(uptime),
    }));
  }

  bool _isProcessAlive(int pid) {
    try {
      // Sending signal 0 checks if process exists without killing it.
      return Process.killPid(pid, ProcessSignal.sigcont);
    } on Object {
      return false;
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h${minutes}m${seconds}s';
    if (minutes > 0) return '${minutes}m${seconds}s';
    return '${seconds}s';
  }
}
