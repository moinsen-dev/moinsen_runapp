import 'dart:convert';
import 'dart:io';

import 'package:moinsen_runapp/src/cli/state_file.dart';
import 'package:moinsen_runapp/src/cli/vm_service_client.dart';

/// Manages the `flutter run` subprocess and captures the VM Service URI.
class CliRunner {
  CliRunner({required this.stateFilePath, this.flutterArgs = const []});

  final String stateFilePath;
  final List<String> flutterArgs;

  Process? _process;
  String? _vmServiceUri;
  String? _device;

  /// The captured VM Service URI, if available.
  String? get vmServiceUri => _vmServiceUri;

  /// Start `flutter run` and stream JSON lines to stdout.
  ///
  /// Returns when the subprocess exits.
  Future<int> start() async {
    _process = await Process.start(
      'flutter',
      ['run', ...flutterArgs],
    );

    // Forward and parse stdout.
    _process!.stdout
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen(_handleStdoutLine);

    // Forward stderr as JSON lines.
    _process!.stderr
        .transform(const SystemEncoding().decoder)
        .transform(const LineSplitter())
        .listen((line) {
      stdout.writeln(
        formatJsonLine(type: 'stderr', data: {'message': line}),
      );
    });

    // Handle signals for clean shutdown.
    ProcessSignal.sigint.watch().listen((_) => stop());
    try {
      ProcessSignal.sigterm.watch().listen((_) => stop());
    } on SignalException {
      // SIGTERM not supported on Windows.
    }

    return _process!.exitCode;
  }

  /// Stop the subprocess.
  void stop() {
    _process?.kill();
    deleteStateFile(path: stateFilePath);
  }

  void _handleStdoutLine(String line) {
    // Try to extract VM Service URI.
    final uri = extractVmServiceUri(line);
    if (uri != null && _vmServiceUri == null) {
      _vmServiceUri = parseVmServiceUri(uri);
      writeStateFile(
        path: stateFilePath,
        vmServiceUri: _vmServiceUri!,
        pid: _process!.pid,
        device: _device ?? 'unknown',
      );
      stdout.writeln(
        formatJsonLine(type: 'started', data: {
          'vmServiceUri': _vmServiceUri,
          'pid': _process!.pid,
          'device': _device ?? 'unknown',
        }),
      );
    }

    // Try to extract device name.
    final device = extractDevice(line);
    if (device != null) {
      _device = device;
    }

    // Forward all output as log lines.
    stdout.writeln(
      formatJsonLine(type: 'stdout', data: {'message': line}),
    );
  }
}

/// Extract the VM Service URI from a flutter run stdout line.
///
/// Matches patterns like:
/// - `The Dart VM service is listening on http://127.0.0.1:PORT/token/`
/// - `An Observatory debugger ... available at: http://...`
String? extractVmServiceUri(String line) {
  final match = RegExp(r'(https?://\S+|wss?://\S+)').firstMatch(line);
  if (match == null) return null;

  final uri = match.group(1)!;
  // Only accept URIs that look like VM Service endpoints (loopback).
  if (uri.contains('127.0.0.1') || uri.contains('localhost')) {
    return uri;
  }
  return null;
}

/// Extract the device name from flutter run output.
///
/// Matches: `Launching lib/main.dart on DEVICE in debug mode...`
String? extractDevice(String line) {
  final match = RegExp(
    'Launching .+ on (.+?) in (debug|profile|release) mode',
  ).firstMatch(line);
  return match?.group(1);
}

/// Format a JSON line for structured output to Claude Code.
String formatJsonLine({
  required String type,
  required Map<String, dynamic> data,
}) {
  return jsonEncode({
    'type': type,
    'timestamp': DateTime.now().toIso8601String(),
    ...data,
  });
}
