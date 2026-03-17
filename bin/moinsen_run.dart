import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/commands/analyze_command.dart';
import 'package:moinsen_runapp/src/cli/commands/context_command.dart';
import 'package:moinsen_runapp/src/cli/commands/errors_command.dart';
import 'package:moinsen_runapp/src/cli/commands/logs_command.dart';
import 'package:moinsen_runapp/src/cli/commands/navigate_command.dart';
import 'package:moinsen_runapp/src/cli/commands/prompt_command.dart';
import 'package:moinsen_runapp/src/cli/commands/reload_command.dart';
import 'package:moinsen_runapp/src/cli/commands/restart_command.dart';
import 'package:moinsen_runapp/src/cli/commands/route_command.dart';
import 'package:moinsen_runapp/src/cli/commands/screenshot_command.dart';
import 'package:moinsen_runapp/src/cli/commands/start_command.dart';
import 'package:moinsen_runapp/src/cli/commands/state_command.dart';
import 'package:moinsen_runapp/src/cli/commands/status_command.dart';
import 'package:moinsen_runapp/src/cli/commands/stop_command.dart';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>(
    'moinsen_run',
    'CLI bridge between a running Flutter app and LLM tools like Claude Code.',
  )
    ..addCommand(StartCommand())
    ..addCommand(StatusCommand())
    ..addCommand(ErrorsCommand())
    ..addCommand(PromptCommand())
    ..addCommand(LogsCommand())
    ..addCommand(NavigateCommand())
    ..addCommand(ReloadCommand())
    ..addCommand(RestartCommand())
    ..addCommand(StateCommand())
    ..addCommand(AnalyzeCommand())
    ..addCommand(ContextCommand())
    ..addCommand(RouteCommand())
    ..addCommand(ScreenshotCommand())
    ..addCommand(StopCommand());

  try {
    // Default to 'start' when no subcommand given.
    if (args.isEmpty || !_isSubcommand(args.first, runner)) {
      await StartCommand().run(args);
    } else {
      await runner.run(args);
    }
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  }
}

bool _isSubcommand(String arg, CommandRunner<void> runner) {
  return runner.commands.containsKey(arg) || arg == '--help' || arg == '-h';
}
