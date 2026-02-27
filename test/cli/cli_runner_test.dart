import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/cli/cli_runner.dart';

void main() {
  group('CliRunner', () {
    group('extractVmServiceUri', () {
      test('extracts URI from standard flutter run output', () {
        const line = 'The Dart VM service is listening on '
            'http://127.0.0.1:52938/yR5v7HOHQ8c=/';
        expect(
          extractVmServiceUri(line),
          'http://127.0.0.1:52938/yR5v7HOHQ8c=/',
        );
      });

      test('extracts URI from verbose flutter output', () {
        const line = 'An Observatory debugger and profiler on '
            'macOS is available at: '
            'http://127.0.0.1:9100/xYz=/';
        expect(
          extractVmServiceUri(line),
          'http://127.0.0.1:9100/xYz=/',
        );
      });

      test('returns null for unrelated output', () {
        expect(extractVmServiceUri('Launching lib/main.dart'), isNull);
        expect(extractVmServiceUri('Syncing files to device'), isNull);
        expect(extractVmServiceUri(''), isNull);
      });

      test('extracts URI with ws:// scheme', () {
        const line =
            'The Dart VM service is listening on ws://127.0.0.1:8888/ws';
        expect(
          extractVmServiceUri(line),
          'ws://127.0.0.1:8888/ws',
        );
      });
    });

    group('extractDevice', () {
      test('extracts device from flutter run output', () {
        const line = 'Launching lib/main.dart on macOS in debug mode...';
        expect(extractDevice(line), 'macOS');
      });

      test('extracts Chrome device', () {
        const line = 'Launching lib/main.dart on Chrome in debug mode...';
        expect(extractDevice(line), 'Chrome');
      });

      test('returns null for unrelated output', () {
        expect(extractDevice('Syncing files'), isNull);
      });
    });

    group('formatJsonLine', () {
      test('formats a log event', () {
        final json = formatJsonLine(type: 'log', data: {'message': 'hello'});
        expect(json, contains('"type":"log"'));
        expect(json, contains('"message":"hello"'));
        expect(json, contains('"timestamp"'));
      });

      test('formats a started event', () {
        final json = formatJsonLine(
          type: 'started',
          data: {'vmServiceUri': 'ws://localhost:1234/ws'},
        );
        expect(json, contains('"type":"started"'));
        expect(json, contains('"vmServiceUri"'));
      });
    });
  });
}
