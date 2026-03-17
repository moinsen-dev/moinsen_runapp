import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/vm_extensions.dart';

void main() {
  group('VM Extension handlers', () {
    late ErrorBucket bucket;
    late ErrorObserver observer;
    late LogBuffer logBuffer;

    setUp(() {
      bucket = ErrorBucket();
      observer = ErrorObserver(bucket: bucket);
      logBuffer = LogBuffer();
    });

    test('getErrors returns empty list when no errors', () {
      final json = handleGetErrors(bucket);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['errors'], isEmpty);
      expect(data['totalCount'], 0);
      expect(data['uniqueCount'], 0);
    });

    test('getErrors returns serialized entries', () {
      bucket.add(
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'flutter',
      );

      final json = handleGetErrors(bucket);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['errors'], hasLength(1));
      expect(data['totalCount'], 1);
      expect(data['uniqueCount'], 1);
      final errors = data['errors'] as List<dynamic>;
      final first = errors[0] as Map<String, dynamic>;
      expect(first['errorType'], 'StateError');
    });

    test('clearErrors clears bucket and observer', () {
      bucket.add(
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'flutter',
      );
      expect(bucket.uniqueCount, 1);

      final json = handleClearErrors(observer);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['cleared'], isTrue);
      expect(bucket.uniqueCount, 0);
    });

    test('getInfo returns metadata', () {
      bucket.add(
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'flutter',
      );

      final json = handleGetInfo(bucket);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['package'], 'moinsen_runapp');
      expect(data['errorCount'], 1);
      expect(data['uniqueErrors'], 1);
      expect(data['platform'], isA<String>());
    });

    test('getLogs returns buffer contents', () {
      logBuffer
        ..add(level: 'error', message: 'boom', source: 'flutter')
        ..add(level: 'info', message: 'ok');

      final json = handleGetLogs(logBuffer);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['logs'], hasLength(2));
      expect(data['capacity'], 200);
      expect(data['size'], 2);
    });

    test('getPrompt returns markdown report', () {
      bucket.add(
        error: StateError('test error'),
        stackTrace: StackTrace.current,
        source: 'flutter',
      );

      final json = handleGetPrompt(bucket, logBuffer);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['prompt'], contains('# Enhanced Bug Report'));
      expect(data['prompt'], contains('StateError'));
    });

    test('getPrompt returns empty report when no errors', () {
      final json = handleGetPrompt(bucket, logBuffer);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['prompt'], contains('# Enhanced Bug Report'));
      expect(data['prompt'], contains('0 unique'));
    });
  });
}
