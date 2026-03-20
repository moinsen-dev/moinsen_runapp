import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/cli_runner.dart';

/// Start `flutter run` and stream structured JSON output.
class StartCommand extends Command<void> {
  @override
  String get name => 'start';

  @override
  String get description =>
      'Start flutter run and stream JSON lines (logs, errors).';

  /// Allow running with arbitrary flutter args.
  @override
  Future<void> run([List<String>? args]) async {
    final stateFilePath = '${Directory.current.path}/.moinsen_run.json';
    final runner = CliRunner(
      stateFilePath: stateFilePath,
      flutterArgs: args ?? argResults?.rest ?? [],
    );
    final exitCode = await runner.start();
    exit(exitCode);
  }
}
