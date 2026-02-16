import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_catcher.dart';
import 'package:moinsen_runapp/src/error_logger.dart';
import 'package:moinsen_runapp/src/error_observer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorCatcher.reportError', () {
    late ErrorBucket bucket;
    late ErrorObserver observer;
    late ErrorLogger logger;
    late ErrorCatcher catcher;

    setUp(() {
      bucket = ErrorBucket();
      observer = ErrorObserver(bucket: bucket);
      logger = ErrorLogger();
      catcher = ErrorCatcher(
        bucket: bucket,
        observer: observer,
        logger: logger,
      );
    });

    test('adds error to bucket and returns entry', () {
      final entry = catcher.reportError(
        StateError('provider failed'),
        StackTrace.current,
        source: 'provider',
      );

      expect(entry, isNotNull);
      expect(entry!.source, 'provider');
      expect(entry.error, isA<StateError>());
      expect(bucket.uniqueCount, 1);
    });

    test('uses default source "app" when not specified', () {
      final entry = catcher.reportError(
        StateError('some error'),
        StackTrace.current,
      );

      expect(entry, isNotNull);
      expect(entry!.source, 'app');
    });

    test('passes diagnostics to bucket entry', () {
      final entry = catcher.reportError(
        StateError('detail error'),
        StackTrace.current,
        source: 'riverpod',
        diagnostics: 'feedProvider failed during refresh',
      );

      expect(entry, isNotNull);
      expect(entry!.diagnostics, 'feedProvider failed during refresh');
    });

    test('returns null when bucket is paused', () {
      bucket.pause();

      final entry = catcher.reportError(
        StateError('paused error'),
        StackTrace.current,
      );

      expect(entry, isNull);
      expect(bucket.uniqueCount, 0);
    });

    test('calls onError callback', () {
      Object? reportedError;
      StackTrace? reportedStack;

      final catcherWithCallback = ErrorCatcher(
        bucket: bucket,
        observer: observer,
        logger: logger,
        onError: (error, stack) {
          reportedError = error;
          reportedStack = stack;
        },
      );

      final error = StateError('callback test');
      final stack = StackTrace.current;

      catcherWithCallback.reportError(error, stack, source: 'provider');

      expect(reportedError, same(error));
      expect(reportedStack, same(stack));
    });

    testWidgets('notifies observer after reporting', (tester) async {
      var notified = false;
      observer.addListener(() => notified = true);

      catcher.reportError(
        StateError('observer test'),
        StackTrace.current,
        source: 'provider',
      );

      // Notification is deferred.
      expect(notified, isFalse);

      await tester.pump(const Duration(milliseconds: 1));

      expect(notified, isTrue);
      expect(observer.hasErrors, isTrue);
    });

    test('deduplicates same error via reportError', () {
      final error = StateError('dedup test');
      final stack = StackTrace.current;

      catcher
        ..reportError(error, stack, source: 'provider')
        ..reportError(error, stack, source: 'provider')
        ..reportError(error, stack, source: 'provider');

      expect(bucket.uniqueCount, 1);
      expect(bucket.totalCount, 3);
    });
  });
}
