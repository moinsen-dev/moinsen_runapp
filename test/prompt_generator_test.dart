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

  group('generateEnhancedReport', () {
    test('generates header with platform', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
      );

      expect(report, contains('# Enhanced Bug Report'));
      expect(report, contains('**Platform:** macos'));
      expect(report, contains('**Errors:** 0 unique, 0 total'));
    });

    test('includes current route in header when provided', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
        currentRoute: '/home',
      );

      expect(report, contains('**Current Route:** /home'));
    });

    test('includes error details', () {
      final entry = ErrorEntry(
        hash: 'abc',
        error: StateError('enhanced error'),
        stackTrace: StackTrace.current,
        source: 'flutter',
        firstSeen: DateTime(2026, 2, 27),
      );

      final report = generateEnhancedReport(
        errors: [entry],
        platform: 'macos',
      );

      expect(report, contains('## Error 1/1: StateError'));
      expect(report, contains('enhanced error'));
      expect(report, contains('**Occurrences:** 1'));
    });

    test('includes recent logs section', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
        recentLogs: [
          {
            'timestamp': '2026-02-27T10:30:45.000',
            'level': 'error',
            'source': 'flutter',
            'message': 'Something broke',
          },
          {
            'timestamp': '2026-02-27T10:30:46.000',
            'level': 'info',
            'message': 'Recovered',
          },
        ],
      );

      expect(report, contains('## Recent Logs (2)'));
      expect(report, contains('**error** (flutter) Something broke'));
      expect(report, contains('**info** Recovered'));
    });

    test('includes navigation history', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
        observerInstalled: true,
        routeHistory: [
          {
            'action': 'push',
            'routeName': '/home',
            'timestamp': '2026-02-27T10:30:00.000',
          },
          {
            'action': 'push',
            'routeName': '/settings',
            'timestamp': '2026-02-27T10:31:00.000',
          },
        ],
      );

      expect(report, contains('## Navigation History'));
      expect(report, contains('push /home'));
      expect(report, contains('push /settings'));
    });

    test('shows "not installed" when observer not installed', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
        observerInstalled: false,
      );

      expect(report, contains('## Navigation'));
      expect(
        report,
        contains('_MoinsenNavigatorObserver not installed._'),
      );
    });

    test('empty logs and history are omitted', () {
      final report = generateEnhancedReport(
        errors: [],
        platform: 'macos',
        observerInstalled: true,
        recentLogs: [],
        routeHistory: [],
      );

      expect(report, isNot(contains('## Recent Logs')));
      expect(report, isNot(contains('## Navigation History')));
      expect(report, isNot(contains('not installed')));
    });
  });
}
