import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/cli/state_file.dart';

void main() {
  late Directory tempDir;
  late String statePath;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('moinsen_test_');
    statePath = '${tempDir.path}/.moinsen_run.json';
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('StateFile', () {
    test('write creates file with expected fields', () {
      writeStateFile(
        path: statePath,
        vmServiceUri: 'ws://127.0.0.1:12345/abc=/ws',
        pid: 42,
        device: 'macos',
      );

      final file = File(statePath);
      expect(file.existsSync(), isTrue);

      final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(data['vmServiceUri'], 'ws://127.0.0.1:12345/abc=/ws');
      expect(data['pid'], 42);
      expect(data['device'], 'macos');
      expect(data['startedAt'], isA<String>());
    });

    test('read returns data from existing file', () {
      writeStateFile(
        path: statePath,
        vmServiceUri: 'ws://127.0.0.1:9999/xyz=/ws',
        pid: 100,
        device: 'chrome',
      );

      final state = readStateFile(path: statePath);
      expect(state, isNotNull);
      expect(state!.vmServiceUri, 'ws://127.0.0.1:9999/xyz=/ws');
      expect(state.pid, 100);
      expect(state.device, 'chrome');
      expect(state.startedAt, isA<DateTime>());
    });

    test('read returns null when file does not exist', () {
      final state = readStateFile(path: '${tempDir.path}/nonexistent.json');
      expect(state, isNull);
    });

    test('read returns null for corrupt file', () {
      File(statePath).writeAsStringSync('not json{{{');

      final state = readStateFile(path: statePath);
      expect(state, isNull);
    });

    test('delete removes the file', () {
      writeStateFile(
        path: statePath,
        vmServiceUri: 'ws://127.0.0.1:1234/ws',
        pid: 1,
        device: 'linux',
      );
      expect(File(statePath).existsSync(), isTrue);

      deleteStateFile(path: statePath);
      expect(File(statePath).existsSync(), isFalse);
    });

    test('delete does not throw when file missing', () {
      expect(
        () => deleteStateFile(path: '${tempDir.path}/missing.json'),
        returnsNormally,
      );
    });
  });
}
