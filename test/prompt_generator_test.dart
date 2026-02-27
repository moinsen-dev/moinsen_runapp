import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/prompt_generator.dart';

void main() {
  group('generateBugReport', () {
    test('returns minimal report for empty error list', () {
      final report = generateBugReport(errors: [], platform: 'macos');

      expect(report, contains('# Bug Report'));
      expect(report, contains('**Errors:** 0 unique'));
    });

    test('includes error type and message for single error', () {
      final entry = ErrorEntry(
        hash: 'abc',
        error: StateError('bad state'),
        stackTrace: StackTrace.current,
        source: 'flutter',
        firstSeen: DateTime(2026, 2, 27),
      );

      final report = generateBugReport(
        errors: [entry],
        platform: 'macos',
      );

      expect(report, contains('## Error 1/1: StateError'));
      expect(report, contains('bad state'));
      expect(report, contains('**Source:**'));
      expect(report, contains('**Occurrences:** 1'));
    });

    test('includes diagnostics section when present', () {
      final entry = ErrorEntry(
        hash: 'abc',
        error: StateError('test'),
        stackTrace: StackTrace.current,
        source: 'flutter',
        diagnostics: 'Widget context info here',
        firstSeen: DateTime(2026, 2, 27),
      );

      final report = generateBugReport(
        errors: [entry],
        platform: 'macos',
      );

      expect(report, contains('### Flutter Diagnostics'));
      expect(report, contains('Widget context info here'));
    });

    test('formats multiple errors with correct numbering', () {
      final errors = List.generate(
        3,
        (i) => ErrorEntry(
          hash: 'hash$i',
          error: StateError('error $i'),
          stackTrace: StackTrace.current,
          source: 'zone',
          firstSeen: DateTime(2026, 2, 27),
        ),
      );

      final report = generateBugReport(
        errors: errors,
        platform: 'android',
      );

      expect(report, contains('## Error 1/3'));
      expect(report, contains('## Error 2/3'));
      expect(report, contains('## Error 3/3'));
      expect(report, contains('**Errors:** 3 unique, 3 total'));
    });

    test('includes platform in header', () {
      final report = generateBugReport(errors: [], platform: 'ios');

      expect(report, contains('**Platform:** ios'));
    });

    test('includes total count from entries with count > 1', () {
      final entry = ErrorEntry(
        hash: 'abc',
        error: StateError('repeated'),
        stackTrace: StackTrace.current,
        source: 'flutter',
        firstSeen: DateTime(2026, 2, 27),
        count: 5,
      );

      final report = generateBugReport(
        errors: [entry],
        platform: 'macos',
      );

      expect(report, contains('**Errors:** 1 unique, 5 total'));
      expect(report, contains('**Occurrences:** 5'));
    });
  });
}
