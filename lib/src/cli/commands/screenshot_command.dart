import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/commands/vm_command.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Capture a screenshot from the running app.
class ScreenshotCommand extends VmCommand {
  ScreenshotCommand() {
    argParser
      ..addOption(
        'path',
        abbr: 'p',
        help: 'Output file path for the screenshot.',
        defaultsTo: './screenshot.png',
      )
      ..addOption(
        'scale',
        abbr: 's',
        help: 'Pixel ratio for the screenshot (0 = device default).',
        defaultsTo: '0',
      )
      ..addFlag(
        'base64',
        help: 'Return PNG bytes inline as base64 instead of writing to disk. '
            'Useful when piping a screenshot into an LLM prompt.',
        negatable: false,
      );
  }

  @override
  String get name => 'screenshot';

  @override
  String get description => 'Capture a screenshot from the running app.';

  @override
  Future<void> execute(MoinsenVmClient client) async {
    final path = argResults?['path'] as String? ?? './screenshot.png';
    final scale =
        double.tryParse(
          argResults?['scale'] as String? ?? '0',
        ) ??
        0;
    final inlineBase64 = argResults?['base64'] as bool? ?? false;

    final result = await client.callMoinsenWithParams(
      'ext.moinsen.screenshot',
      params: {if (scale > 0) 'scale': scale.toString()},
    );

    if (result == null || result['error'] != null) {
      stdout.writeln(
        jsonEncode(
          result ?? {'error': 'No response from app'},
        ),
      );
      return;
    }

    final base64Data = result['screenshot'] as String;

    if (inlineBase64) {
      stdout.writeln(
        jsonEncode({
          'base64': base64Data,
          'width': result['width'],
          'height': result['height'],
          'bytes': base64Decode(base64Data).length,
        }),
      );
      return;
    }

    final bytes = base64Decode(base64Data);
    final file = File(path);
    await file.writeAsBytes(bytes);

    stdout.writeln(
      jsonEncode({
        'path': file.absolute.path,
        'width': result['width'],
        'height': result['height'],
        'bytes': bytes.length,
      }),
    );
  }
}
