import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_entry.dart';

void main() {
  group('ErrorEntry', () {
    test('creates with default values', () {
      final now = DateTime.now();
      final entry = ErrorEntry(
        hash: 'test_hash',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'flutter',
        firstSeen: now,
      );

      expect(entry.hash, 'test_hash');
      expect(entry.source, 'flutter');
      expect(entry.count, 1);
      expect(entry.firstSeen, now);
      expect(entry.lastSeen, now);
    });

    test('label truncates long messages', () {
      final longMessage = 'x' * 200;
      final entry = ErrorEntry(
        hash: 'hash',
        error: StateError(longMessage),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      expect(entry.label.length, lessThanOrEqualTo(120));
      expect(entry.label, endsWith('...'));
    });

    test('label does not truncate short messages', () {
      final entry = ErrorEntry(
        hash: 'hash',
        error: StateError('short'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      expect(entry.label, isNot(endsWith('...')));
    });

    test('span returns duration between first and last seen', () {
      final first = DateTime(2024);
      final last = DateTime(2024, 1, 1, 0, 0, 5);

      final entry = ErrorEntry(
        hash: 'hash',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: first,
        lastSeen: last,
        count: 10,
      );

      expect(entry.span, const Duration(seconds: 5));
    });
  });
}
