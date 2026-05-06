import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:moinsen_runapp/src/cli/commands/analyze_command.dart';
import 'package:moinsen_runapp/src/cli/commands/await_element_command.dart';
import 'package:moinsen_runapp/src/cli/commands/await_route_command.dart';
import 'package:moinsen_runapp/src/cli/commands/context_command.dart';
import 'package:moinsen_runapp/src/cli/commands/device_command.dart';
import 'package:moinsen_runapp/src/cli/commands/elements_command.dart';
import 'package:moinsen_runapp/src/cli/commands/enter_text_command.dart';
import 'package:moinsen_runapp/src/cli/commands/errors_command.dart';
import 'package:moinsen_runapp/src/cli/commands/inspect_command.dart';
import 'package:moinsen_runapp/src/cli/commands/install_skill_command.dart';
import 'package:moinsen_runapp/src/cli/commands/lifecycle_command.dart';
import 'package:moinsen_runapp/src/cli/commands/logs_command.dart';
import 'package:moinsen_runapp/src/cli/commands/navigate_command.dart';
import 'package:moinsen_runapp/src/cli/commands/network_command.dart';
import 'package:moinsen_runapp/src/cli/commands/pregrant_command.dart';
import 'package:moinsen_runapp/src/cli/commands/prompt_command.dart';
import 'package:moinsen_runapp/src/cli/commands/reload_command.dart';
import 'package:moinsen_runapp/src/cli/commands/restart_command.dart';
import 'package:moinsen_runapp/src/cli/commands/route_command.dart';
import 'package:moinsen_runapp/src/cli/commands/screenshot_command.dart';
import 'package:moinsen_runapp/src/cli/commands/scroll_to_command.dart';
import 'package:moinsen_runapp/src/cli/commands/start_command.dart';
import 'package:moinsen_runapp/src/cli/commands/state_command.dart';
import 'package:moinsen_runapp/src/cli/commands/status_command.dart';
import 'package:moinsen_runapp/src/cli/commands/stop_command.dart';
import 'package:moinsen_runapp/src/cli/commands/tap_command.dart';

Future<void> main(List<String> args) async {
  final runner =
      CommandRunner<void>(
          'moinsen_run',
          'CLI bridge between a running Flutter app '
              'and LLM tools like Claude Code.',
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
        ..addCommand(AwaitElementCommand())
        ..addCommand(AwaitRouteCommand())
        ..addCommand(ContextCommand())
        ..addCommand(DeviceCommand())
        ..addCommand(ElementsCommand())
        ..addCommand(EnterTextCommand())
        ..addCommand(InspectCommand())
        ..addCommand(InstallSkillCommand())
        ..addCommand(LifecycleCommand())
        ..addCommand(NetworkCommand())
        ..addCommand(PregrantCommand())
        ..addCommand(RouteCommand())
        ..addCommand(ScreenshotCommand())
        ..addCommand(ScrollToCommand())
        ..addCommand(StopCommand())
        ..addCommand(TapCommand());

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
