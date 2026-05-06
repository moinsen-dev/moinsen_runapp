import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Poll the running app's interactive element list until a target widget is
/// present (and visible by default), then exit. Designed for scripted flows
/// that issue `tap`/`enter-text` after a navigation, where the widget tree
/// hasn't finished rebuilding yet on the first frame.
///
/// Usage:
///   moinsen_run await-element --key btn_setup_next
///   moinsen_run await-element --text 'Continue' --timeout 3s
///
/// Exits 0 on match, 1 on timeout. JSON output: `{matched, attempts,
/// elapsed_ms, key|text}`.
class AwaitElementCommand extends VmCommand {
  AwaitElementCommand() {
    argParser
      ..addOption('key', help: 'ValueKey<String> of the widget to wait for')
      ..addOption('text', help: 'Text content of the widget to wait for')
      ..addOption(
        'timeout',
        abbr: 't',
        help: 'Max wait duration. Suffix with `ms` or `s`.',
        defaultsTo: '5s',
      )
      ..addOption(
        'interval',
        abbr: 'i',
        help: 'Poll interval (ms).',
        defaultsTo: '200',
      );
  }

  @override
  String get name => 'await-element';

  @override
  String get description =>
      'Poll until an interactive element is present, with timeout.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final keyArg = argResults?['key'] as String?;
    final textArg = argResults?['text'] as String?;
    if (keyArg == null && textArg == null) {
      stderr.writeln(
        jsonEncode({'error': 'Specify --key or --text'}),
      );
      exit(1);
    }
    final timeout = _parseDuration(argResults?['timeout'] as String? ?? '5s');
    final interval = Duration(
      milliseconds:
          int.tryParse(argResults?['interval'] as String? ?? '200') ?? 200,
    );

    final stopwatch = Stopwatch()..start();
    var attempts = 0;

    while (stopwatch.elapsed < timeout) {
      attempts++;
      final result = await client.callMoinsen(
        'ext.moinsen.getInteractiveElements',
      );
      final elements = result?['elements'] as List<dynamic>? ?? const [];

      for (final raw in elements) {
        if (raw is! Map<String, dynamic>) continue;
        final visible = raw['visible'] as bool? ?? true;
        if (!visible) continue;
        if (keyArg != null && raw['key'] == keyArg) {
          _emit(true, attempts, stopwatch, raw);
          return;
        }
        if (textArg != null && raw['text'] == textArg) {
          _emit(true, attempts, stopwatch, raw);
          return;
        }
      }
      await Future<void>.delayed(interval);
    }

    stopwatch.stop();
    stdout.writeln(
      jsonEncode({
        'matched': false,
        'key': keyArg,
        'text': textArg,
        'attempts': attempts,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'error': 'Timeout waiting for element',
      }),
    );
    exit(1);
  }

  void _emit(
    bool matched,
    int attempts,
    Stopwatch sw,
    Map<String, dynamic> element,
  ) {
    sw.stop();
    stdout.writeln(
      jsonEncode({
        'matched': matched,
        'attempts': attempts,
        'elapsed_ms': sw.elapsedMilliseconds,
        'element': {
          'type': element['type'],
          'key': element['key'],
          'text': element['text'],
        },
      }),
    );
  }
}

Duration _parseDuration(String input) {
  final trimmed = input.trim().toLowerCase();
  if (trimmed.endsWith('ms')) {
    return Duration(
      milliseconds:
          int.tryParse(trimmed.substring(0, trimmed.length - 2)) ?? 5000,
    );
  }
  if (trimmed.endsWith('s')) {
    return Duration(
      seconds:
          int.tryParse(trimmed.substring(0, trimmed.length - 1)) ?? 5,
    );
  }
  return Duration(milliseconds: int.tryParse(trimmed) ?? 5000);
}
