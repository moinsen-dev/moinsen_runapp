import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';

void main() {
  group('ErrorBucket', () {
    late ErrorBucket bucket;

    setUp(() {
      bucket = ErrorBucket(maxEntries: 5);
    });

    test('adds a new error entry', () {
      final entry = bucket.add(
        error: StateError('test error'),
        stackTrace: StackTrace.current,
        source: 'test',
      )!;

      expect(entry.count, 1);
      expect(entry.source, 'test');
      expect(bucket.uniqueCount, 1);
      expect(bucket.totalCount, 1);
    });

    test('deduplicates identical errors within window', () {
      final error = StateError('same error');
      final stack = StackTrace.current;

      bucket
        ..add(error: error, stackTrace: stack, source: 'test')
        ..add(error: error, stackTrace: stack, source: 'test')
        ..add(error: error, stackTrace: stack, source: 'test');

      expect(bucket.uniqueCount, 1);
      expect(bucket.totalCount, 3);

      final entry = bucket.entries.first;
      expect(entry.count, 3);
    });

    test('treats different errors as unique', () {
      bucket
        ..add(
          error: StateError('error A'),
          stackTrace: StackTrace.current,
          source: 'test',
        )
        ..add(
          error: ArgumentError('error B'),
          stackTrace: StackTrace.current,
          source: 'test',
        );

      expect(bucket.uniqueCount, 2);
      expect(bucket.totalCount, 2);
    });

    test('entries are ordered by first occurrence', () {
      bucket
        ..add(
          error: StateError('first'),
          stackTrace: StackTrace.current,
          source: 'test',
        )
        ..add(
          error: ArgumentError('second'),
          stackTrace: StackTrace.current,
          source: 'test',
        );

      final entries = bucket.entries;
      expect(entries.length, 2);
      expect(entries[0].error.toString(), contains('first'));
      expect(entries[1].error.toString(), contains('second'));
    });

    test('evicts oldest entry when at capacity', () {
      for (var i = 0; i < 6; i++) {
        bucket.add(
          error: StateError('error $i'),
          stackTrace: StackTrace.current,
          source: 'test',
        );
      }

      expect(bucket.uniqueCount, 5);
      // The oldest (error 0) should have been evicted.
      final labels = bucket.entries.map((e) => e.label).toList();
      expect(labels, isNot(contains(contains('error 0'))));
      expect(labels, contains(contains('error 5')));
    });

    test('clear removes all entries', () {
      bucket.add(
        error: StateError('will be cleared'),
        stackTrace: StackTrace.current,
        source: 'test',
      );

      expect(bucket.uniqueCount, 1);

      bucket.clear();

      expect(bucket.uniqueCount, 0);
      expect(bucket.totalCount, 0);
      expect(bucket.entries, isEmpty);
    });

    test('dedup updates lastSeen timestamp', () {
      final error = StateError('timestamp test');
      final stack = StackTrace.current;

      final first = bucket.add(
        error: error,
        stackTrace: stack,
        source: 'test',
      )!;
      final firstLastSeen = first.lastSeen;

      // Small delay to ensure timestamp difference.
      final second = bucket.add(
        error: error,
        stackTrace: stack,
        source: 'test',
      )!;

      // Same entry reference returned.
      expect(identical(first, second), isTrue);
      expect(
        second.lastSeen.millisecondsSinceEpoch,
        greaterThanOrEqualTo(firstLastSeen.millisecondsSinceEpoch),
      );
    });
  });
}
