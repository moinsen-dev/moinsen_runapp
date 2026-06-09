import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Diagnose why the running app appears frozen or stuck.
///
/// Surfaces the current execution stack, the async awaiter chain, the queued
/// microtask backlog, and any overdue timers — the signatures of async
/// deadlocks, microtask floods, and event-loop starvation.
class HangCommand extends VmCommand {
  HangCommand() {
    argParser.addOption(
      'timer-watch-ms',
      abbr: 't',
      help: 'How long to watch for overdue timers, in ms (0 to skip).',
      defaultsTo: '1500',
    );
  }

  @override
  String get name => 'hang';

  @override
  String get description =>
      'Diagnose a frozen/stuck app (stack, microtasks, overdue timers).';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final ms = int.tryParse(argResults?['timer-watch-ms'] as String? ?? '1500');
    final result = await client.diagnoseHang(
      timerWatch: Duration(milliseconds: ms ?? 1500),
    );

    stdout.writeln(
      jsonEncode(result ?? {'error': 'No main isolate found'}),
    );
  }
}
