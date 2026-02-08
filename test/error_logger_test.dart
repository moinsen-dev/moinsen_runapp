import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/error_logger.dart';

void main() {
  group('ErrorLogger', () {
    late ErrorLogger logger;

    setUp(() {
      logger = ErrorLogger();
    });

    test('logs first occurrence and returns true', () {
      final entry = ErrorEntry(
        hash: 'abc123',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      expect(logger.log(entry), isTrue);
    });

    test('suppresses duplicate and returns false', () {
      final entry = ErrorEntry(
        hash: 'abc123',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      logger.log(entry); // first
      expect(logger.log(entry), isFalse); // duplicate
    });

    test('logs different hashes independently', () {
      final entryA = ErrorEntry(
        hash: 'hash_a',
        error: StateError('error A'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );
      final entryB = ErrorEntry(
        hash: 'hash_b',
        error: StateError('error B'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      expect(logger.log(entryA), isTrue);
      expect(logger.log(entryB), isTrue);
    });

    test('reset clears logged hashes and burst state', () {
      final entry = ErrorEntry(
        hash: 'abc123',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'test',
        firstSeen: DateTime.now(),
      );

      logger.log(entry);
      expect(logger.log(entry), isFalse);

      logger.reset();
      expect(logger.log(entry), isTrue);
    });

    test('burst limiting activates after threshold', () {
      final burstLogger = ErrorLogger(burstThreshold: 3);

      // Log 5 unique errors in rapid succession.
      for (var i = 0; i < 5; i++) {
        final entry = ErrorEntry(
          hash: 'hash_$i',
          error: StateError('error $i'),
          stackTrace: StackTrace.current,
          source: 'test',
          firstSeen: DateTime.now(),
        );
        expect(burstLogger.log(entry), isTrue);
      }

      // All 5 were logged (returns true), but after #3
      // the output format switches to compressed.
      // We verify no crash and all entries accepted.
    });
  });
}
