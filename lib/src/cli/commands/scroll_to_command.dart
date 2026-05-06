import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';
import 'package:moinsen_runapp/src/interaction/retry_strategy.dart';

/// Scroll until a target element becomes visible.
class ScrollToCommand extends VmCommand {
  ScrollToCommand() {
    argParser
      ..addOption('key', help: 'ValueKey<String> of the target widget')
      ..addOption('text', help: 'Text content of the target widget')
      ..addFlag(
        'no-retry',
        help: 'Disable retry-with-backoff (test-suite mode).',
        negatable: false,
      );
  }

  @override
  String get name => 'scroll-to';

  @override
  String get description => 'Scroll until target element is visible.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final params = <String, String>{};
    for (final key in ['key', 'text']) {
      final value = argResults?[key] as String?;
      if (value != null) params[key] = value;
    }

    if (params.isEmpty) {
      stderr.writeln(
        jsonEncode({
          'error': 'Specify --key or --text',
        }),
      );
      exit(1);
    }
    final noRetry = argResults?['no-retry'] as bool? ?? false;

    final result = noRetry
        ? await client.callMoinsenWithParams(
            'ext.moinsen.scrollTo',
            params: params,
          )
        : await retryWithBackoff(
            () => client.callMoinsenWithParams(
              'ext.moinsen.scrollTo',
              params: params,
            ),
          );
    stdout.writeln(
      jsonEncode(
        result ?? <String, dynamic>{'success': false},
      ),
    );
  }
}
