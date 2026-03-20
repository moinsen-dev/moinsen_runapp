import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/moinsen_runapp.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moinsenLog', () {
    late LogBuffer buffer;

    setUp(() {
      buffer = LogBuffer();
      setupTestLogBuffer(buffer);
    });

    tearDown(resetGlobalLogBuffer);

    test('writes to the buffer when initialized', () {
      moinsenLog('hello world');

      expect(buffer.size, 1);
      expect(buffer.entries.first.message, 'hello world');
    });

    test('is graceful when buffer is not initialized', () {
      resetGlobalLogBuffer();

      // Should not throw.
      moinsenLog('orphan message');
    });

    test('default level is info', () {
      moinsenLog('default level');

      expect(buffer.entries.first.level, 'info');
    });

    test('custom level is passed through', () {
      moinsenLog('warn msg', level: 'warning');

      expect(buffer.entries.first.level, 'warning');
    });

    test('custom source is preserved', () {
      moinsenLog('nav event', source: 'router');

      expect(buffer.entries.first.source, 'router');
    });

    test('source defaults to null when not provided', () {
      moinsenLog('no source');

      expect(buffer.entries.first.source, isNull);
    });

    test('level, source, and message are correctly passed through', () {
      moinsenLog(
        'API call completed',
        level: 'error',
        source: 'http_client',
      );

      final entry = buffer.entries.first;
      expect(entry.level, 'error');
      expect(entry.message, 'API call completed');
      expect(entry.source, 'http_client');
    });

    test('resetGlobalLogBuffer clears the global reference', () {
      resetGlobalLogBuffer();

      // After reset, logging should be a no-op (no crash, no entries).
      moinsenLog('should be ignored');
      expect(buffer.size, 0);
    });
  });
}
