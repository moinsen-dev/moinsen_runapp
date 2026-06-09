import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/moinsen_event.dart';
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

    test('getCapabilities reports version, extensions and features', () {
      final data = jsonDecode(handleGetCapabilities()) as Map<String, dynamic>;

      expect(data['package'], 'moinsen_runapp');
      expect(data['version'], moinsenRunappVersion);
      expect(data['protocol'], 1);

      final exts = (data['extensions'] as List).cast<String>();
      // Self-describing + a representative spread of the surface.
      expect(exts, contains('getCapabilities'));
      expect(exts, containsAll(['getErrors', 'getState', 'getNetwork', 'tap']));
      expect(exts, equals(moinsenExtensions));

      final features = data['features'] as Map<String, dynamic>;
      expect(features['network'], isTrue);
      expect(features['interaction'], isTrue);
      expect(features['events'], isTrue);
    });

    test('emitMoinsenEvent never throws without a VM Service', () {
      expect(moinsenEventKind, 'moinsen');
      expect(
        () => emitMoinsenEvent('error', {'total': 1, 'unique': 1}),
        returnsNormally,
      );
    });

    test('getProjectBrain finds a manifest above the start dir', () {
      final tmp = Directory.systemTemp.createTempSync('mrb_brain_');
      addTearDown(() => tmp.deleteSync(recursive: true));
      Directory('${tmp.path}/.moinsen').createSync();
      File('${tmp.path}/.moinsen/manifest.json')
          .writeAsStringSync('{"identity":{"name":"demo"}}');
      final nested = Directory('${tmp.path}/app/lib')..createSync(recursive: true);

      final data = jsonDecode(handleGetProjectBrain(start: nested))
          as Map<String, dynamic>;

      expect(data['available'], isTrue);
      expect(data['path'], endsWith('.moinsen/manifest.json'));
      expect(
        ((data['manifest'] as Map)['identity'] as Map)['name'],
        'demo',
      );
    });

    test('getProjectBrain reports unavailable when no manifest is reachable', () {
      final tmp = Directory.systemTemp.createTempSync('mrb_nobrain_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final data = jsonDecode(handleGetProjectBrain(start: tmp))
          as Map<String, dynamic>;

      expect(data['available'], isFalse);
      expect(data.containsKey('manifest'), isFalse);
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

    test('getLifecycle returns state when not installed', () {
      final json = handleGetLifecycle();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['currentState'], 'unknown');
      expect(data['history'], isEmpty);
    });

    test('getDeviceInfo returns device context', () {
      final json = handleGetDeviceInfo();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data, containsPair('os', isA<String>()));
      expect(data, containsPair('devicePixelRatio', isA<double>()));
      expect(data, containsPair('logicalWidth', isA<double>()));
      expect(data, containsPair('locale', isA<String>()));
      expect(data, containsPair('platformBrightness', isA<String>()));
      expect(
        data,
        containsPair('accessibilityFeatures', isA<Map<String, dynamic>>()),
      );
    });

    test('getPrompt returns empty report when no errors', () {
      final json = handleGetPrompt(bucket, logBuffer);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['prompt'], contains('# Enhanced Bug Report'));
      expect(data['prompt'], contains('0 unique'));
    });
  });
}
