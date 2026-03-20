import 'package:args/command_runner.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  group('CLI Commands', () {
    late CommandRunner<void> runner;

    setUp(() {
      runner = CommandRunner<void>('moinsen_run', 'test')
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
    });

    test('all 14 commands are registered', () {
      expect(
        runner.commands.keys,
        containsAll([
          'start',
          'status',
          'errors',
          'prompt',
          'logs',
          'navigate',
          'reload',
          'restart',
          'state',
          'analyze',
          'context',
          'route',
          'screenshot',
          'stop',
        ]),
      );
      expect(runner.commands.length, 15); // 14 + help
    });

    test('start command has correct name and description', () {
      expect(runner.commands['start']!.name, 'start');
      expect(
        runner.commands['start']!.description,
        contains('flutter run'),
      );
    });

    test('logs command accepts --last flag', () {
      final logsCmd = runner.commands['logs']!;
      expect(
        logsCmd.argParser.options.containsKey('last'),
        isTrue,
      );
    });

    test('errors command has correct name', () {
      expect(runner.commands['errors']!.name, 'errors');
    });

    test('prompt command has correct name', () {
      expect(runner.commands['prompt']!.name, 'prompt');
    });

    test('reload command has correct name', () {
      expect(runner.commands['reload']!.name, 'reload');
    });

    test('restart command has correct name', () {
      expect(runner.commands['restart']!.name, 'restart');
    });

    test('analyze command has correct name', () {
      expect(runner.commands['analyze']!.name, 'analyze');
    });

    test('stop command has correct name', () {
      expect(runner.commands['stop']!.name, 'stop');
    });

    test('navigate command has correct name', () {
      expect(runner.commands['navigate']!.name, 'navigate');
    });

    test('state command has correct name', () {
      expect(runner.commands['state']!.name, 'state');
    });
  });
}
