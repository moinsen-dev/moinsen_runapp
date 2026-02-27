import 'dart:convert';
import 'dart:io';

/// Parsed contents of `.moinsen_run.json`.
class RunState {
  RunState({
    required this.vmServiceUri,
    required this.pid,
    required this.device,
    required this.startedAt,
  });

  final String vmServiceUri;
  final int pid;
  final String device;
  final DateTime startedAt;
}

/// Write the state file with current run metadata.
void writeStateFile({
  required String path,
  required String vmServiceUri,
  required int pid,
  required String device,
}) {
  final data = {
    'vmServiceUri': vmServiceUri,
    'pid': pid,
    'device': device,
    'startedAt': DateTime.now().toIso8601String(),
  };
  File(path).writeAsStringSync(jsonEncode(data));
}

/// Read and parse the state file. Returns `null` if missing or corrupt.
RunState? readStateFile({required String path}) {
  final file = File(path);
  if (!file.existsSync()) return null;

  try {
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return RunState(
      vmServiceUri: data['vmServiceUri'] as String,
      pid: data['pid'] as int,
      device: data['device'] as String,
      startedAt: DateTime.parse(data['startedAt'] as String),
    );
  } on Object {
    return null;
  }
}

/// Delete the state file. No-op if it doesn't exist.
void deleteStateFile({required String path}) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}
