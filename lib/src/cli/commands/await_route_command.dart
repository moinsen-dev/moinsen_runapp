import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Poll the running app until its current route matches the expected path,
/// then exit. Designed for scripted flows that navigate via tap and need to
/// wait for the destination route to settle before issuing the next command.
///
/// Usage:
///   moinsen_run await-route /onboarding/setup --timeout 8s
///
/// Exits 0 on match, 1 on timeout. JSON output: `{matched, attempts,
/// elapsed_ms, currentRoute}`.
class AwaitRouteCommand extends VmCommand {
  AwaitRouteCommand() {
    argParser
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
      )
      ..addFlag(
        'startsWith',
        help: 'Match if currentRoute starts with the expected path '
            '(default: exact equality).',
        negatable: false,
      );
  }

  @override
  String get name => 'await-route';

  @override
  String get description =>
      'Poll until current route matches the given path, with timeout.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final rest = argResults?.rest ?? const <String>[];
    if (rest.isEmpty) {
      stderr.writeln(
        jsonEncode({
          'error':
              'Usage: moinsen_run await-route <path> [--timeout 5s] '
                  '[--startsWith]',
        }),
      );
      exit(1);
    }
    final expected = rest.first;
    final timeout = _parseDuration(argResults?['timeout'] as String? ?? '5s');
    final interval = Duration(
      milliseconds:
          int.tryParse(argResults?['interval'] as String? ?? '200') ?? 200,
    );
    final startsWith = argResults?['startsWith'] as bool? ?? false;

    final stopwatch = Stopwatch()..start();
    var attempts = 0;
    String? lastRoute;

    while (stopwatch.elapsed < timeout) {
      attempts++;
      final result = await client.callMoinsen('ext.moinsen.getRoute');
      final current = result?['currentRoute'] as String?;
      lastRoute = current;

      if (current != null) {
        final matched = startsWith
            ? current.startsWith(expected)
            : current == expected;
        if (matched) {
          stopwatch.stop();
          stdout.writeln(
            jsonEncode({
              'matched': true,
              'currentRoute': current,
              'attempts': attempts,
              'elapsed_ms': stopwatch.elapsedMilliseconds,
            }),
          );
          return;
        }
      }
      await Future<void>.delayed(interval);
    }

    stopwatch.stop();
    stdout.writeln(
      jsonEncode({
        'matched': false,
        'currentRoute': lastRoute,
        'expected': expected,
        'attempts': attempts,
        'elapsed_ms': stopwatch.elapsedMilliseconds,
        'error': 'Timeout waiting for route',
      }),
    );
    exit(1);
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
