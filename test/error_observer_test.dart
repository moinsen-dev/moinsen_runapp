import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';

void main() {
  // Needed for SchedulerBinding.addPostFrameCallback.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorObserver', () {
    late ErrorBucket bucket;
    late ErrorObserver observer;

    setUp(() {
      bucket = ErrorBucket();
      observer = ErrorObserver(bucket: bucket);
    });

    test('hasErrors is false initially', () {
      expect(observer.hasErrors, isFalse);
      expect(observer.totalErrorCount, 0);
      expect(observer.uniqueErrorCount, 0);
    });

    testWidgets(
      'notifies listeners after frame when error is added',
      (tester) async {
        var notified = false;
        observer.addListener(() => notified = true);

        bucket.add(
          error: StateError('test'),
          stackTrace: StackTrace.current,
          source: 'test',
        );
        observer.onErrorAdded();

        // Not immediate — notification is deferred.
        expect(notified, isFalse);

        // Pump with non-zero duration so FakeAsync.elapse()
        // processes the Timer.run() callback.
        await tester.pump(const Duration(milliseconds: 1));

        expect(notified, isTrue);
        expect(observer.hasErrors, isTrue);
        expect(observer.totalErrorCount, 1);
        expect(observer.uniqueErrorCount, 1);
      },
    );

    testWidgets(
      'coalesces multiple errors into one notification',
      (tester) async {
        var notifyCount = 0;
        observer.addListener(() => notifyCount++);

        // Add 3 different errors in the same frame.
        for (var i = 0; i < 3; i++) {
          bucket.add(
            error: StateError('error $i'),
            stackTrace: StackTrace.current,
            source: 'test',
          );
          observer.onErrorAdded();
        }

        // Before pump — no notifications yet.
        expect(notifyCount, 0);

        await tester.pump(const Duration(milliseconds: 1));

        // Only one notification despite 3 errors.
        expect(notifyCount, 1);
        expect(observer.uniqueErrorCount, 3);
      },
    );

    testWidgets(
      'notifies on dedup count change',
      (tester) async {
        final error = StateError('same error');
        final stack = StackTrace.current;

        bucket.add(
          error: error,
          stackTrace: stack,
          source: 'test',
        );
        observer.onErrorAdded();
        await tester.pump(const Duration(milliseconds: 1));

        var notified = false;
        observer.addListener(() => notified = true);

        bucket.add(
          error: error,
          stackTrace: stack,
          source: 'test',
        );
        observer.onErrorAdded();
        await tester.pump(const Duration(milliseconds: 1));

        expect(notified, isTrue);
        expect(observer.totalErrorCount, 2);
        expect(observer.uniqueErrorCount, 1);
      },
    );

    test('clearErrors resets state and notifies synchronously', () {
      bucket.add(
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'test',
      );
      // Directly update counts to match bucket state.
      observer.onErrorAdded();

      var notified = false;
      // clearErrors notifies synchronously (it's user-initiated).
      observer
        ..addListener(() => notified = true)
        ..clearErrors();

      expect(notified, isTrue);
      expect(observer.hasErrors, isFalse);
      expect(observer.totalErrorCount, 0);
      expect(observer.uniqueErrorCount, 0);
      expect(observer.errors, isEmpty);
    });

    testWidgets(
      'does not notify when state unchanged',
      (tester) async {
        var notifyCount = 0;
        // Call without any errors added — no state change.
        observer
          ..addListener(() => notifyCount++)
          ..onErrorAdded();
        await tester.pump(const Duration(milliseconds: 1));

        expect(notifyCount, 0);
      },
    );
  });
}
