import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart' as logging;
import 'package:mcp_dart/mcp_dart.dart';
import 'package:moinsen_runapp/src/mcp/moinsen_connector.dart';
import 'package:moinsen_runapp/src/mcp/moinsen_tools.dart';

const _version = '0.6.0';

Future<int> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('version', negatable: false)
    ..addOption('log-level', abbr: 'l', defaultsTo: 'INFO')
    ..addOption('log-file');

  try {
    final args = parser.parse(arguments);

    if (args.flag('help')) {
      stderr
        ..writeln(
          'moinsen_mcp — MCP server for Flutter app '
          'observation and remote control',
        )
        ..writeln()
        ..writeln('Usage: moinsen_mcp [options]')
        ..writeln()
        ..writeln('Options:')
        ..writeln(parser.usage);
      return 0;
    }

    if (args.flag('version')) {
      stderr.writeln('moinsen_mcp $_version');
      return 0;
    }

    _setupLogging(
      (args.option('log-level') ?? 'INFO').toUpperCase(),
      args.option('log-file'),
    );

    final connector = MoinsenConnector();

    final server = McpServer(
      const Implementation(name: 'moinsen-runapp-mcp', version: _version),
      options: const McpServerOptions(
        capabilities: ServerCapabilities(tools: ServerCapabilitiesTools()),
        instructions: '''
MoinsenRunApp MCP enables AI agents to observe, debug, and remote-control Flutter apps running in debug mode.

## Setup
1. Ensure the Flutter app uses `moinsenRunApp(child: ...)` from the moinsen_runapp package.
2. For interaction features (tap, scroll, enter_text), add `enableInteraction: true` to RunAppConfig.
3. Start the app in debug mode and note the VM service URI.
4. Use the "connect" tool with the VM service URI.

## Available Tool Categories

**Observation:** get_errors, get_logs, get_route, get_network, get_lifecycle, get_device_info, get_state, take_screenshot, get_prompt
**Interaction:** get_interactive_elements, tap, enter_text, scroll_to (require enableInteraction)
**Control:** navigate, hot_reload, hot_restart, clear_errors
**Composite:** observe (full context + screenshot + elements), interact_and_verify (action + verification screenshot)

## Tips
- Start with "observe" to understand the full app state
- Use "get_interactive_elements" to see what can be tapped
- Match elements by key (most reliable), text, type, or coordinates
- Use "interact_and_verify" to perform an action and immediately see the result
''',
      ),
    );

    registerMoinsenTools(server, connector);

    final transport = StdioServerTransport();
    final logger = logging.Logger('main');

    try {
      logger.fine('Starting MCP server on stdio');
      await server.connect(transport);
      logger.info('Server started');
    } on Object catch (e, st) {
      logger.severe('Failed to start', e, st);
      return 1;
    }

    final signal = await _waitForExit();
    logger.info('Received ${signal.name}, stopping');

    await server.close();
    await transport.close();
    return 0;
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    return 1;
  }
}

void _setupLogging(String levelName, String? logFile) {
  final level = logging.Level.LEVELS.firstWhere(
    (e) => e.name == levelName,
    orElse: () => logging.Level.INFO,
  );

  logging.Logger.root.level = level;

  if (logFile != null) {
    final file = File(logFile)..createSync(recursive: true);
    logging.Logger.root.onRecord.listen((record) {
      file.writeAsStringSync(
        '[${record.level.name}][${record.loggerName}]'
        '[${_fmt(record.time)}] ${record.message}\n',
        mode: FileMode.append,
      );
    });
  } else {
    logging.Logger.root.onRecord.listen((record) {
      stderr.writeln(
        '[${record.level.name}][${record.loggerName}]'
        '[${_fmt(record.time)}] ${record.message}',
      );
    });
  }
}

String _fmt(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:'
    '${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';

Future<ProcessSignal> _waitForExit() {
  final completer = Completer<ProcessSignal>();
  late final StreamSubscription<ProcessSignal> sigterm;
  late final StreamSubscription<ProcessSignal> sigint;

  void handle(ProcessSignal signal) {
    if (!completer.isCompleted) {
      completer.complete(signal);
      unawaited(sigterm.cancel());
      unawaited(sigint.cancel());
    }
  }

  sigterm = ProcessSignal.sigterm.watch().listen(handle);
  sigint = ProcessSignal.sigint.watch().listen(handle);
  return completer.future;
}
