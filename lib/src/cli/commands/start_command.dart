import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/cli_runner.dart';

/// Start `flutter run` and stream structured JSON output.
class StartCommand extends Command<void> {
  StartCommand() {
    argParser.addOption(
      'device',
      abbr: 'd',
      help: 'Target device id (forwarded as `--device <id>` to flutter run). '
          'Skip and use `--` passthrough for ad-hoc args.',
    );
  }

  @override
  String get name => 'start';

  @override
  String get description =>
      'Start flutter run and stream JSON lines (logs, errors).';

  /// Allow running with arbitrary flutter args. The `--device <id>` flag is
  /// promoted out of `--`-passthrough so scripted starts don't need the
  /// awkward `moinsen_run start -- -d <id>` dance.
  @override
  Future<void> run([List<String>? args]) async {
    final stateFilePath = '${Directory.current.path}/.moinsen_run.json';
    final passthrough = List<String>.of(args ?? argResults?.rest ?? const []);
    final device = argResults?['device'] as String?;
    if (device != null && device.isNotEmpty) {
      passthrough
        ..add('-d')
        ..add(device);
    }
    final runner = CliRunner(
      stateFilePath: stateFilePath,
      flutterArgs: passthrough,
    );
    final exitCode = await runner.start();
    exit(exitCode);
  }
}
