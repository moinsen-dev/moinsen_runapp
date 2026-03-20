import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/context_generator.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

void main() {
  group('generateContext', () {
    test('generates minimal report with empty data', () {
      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
      );

      expect(report, contains('# App Context Report'));
      expect(report, contains('**Platform:** macos'));
      expect(report, contains('**Errors:** 0 unique, 0 total'));
    });

    test('includes error summaries when errors provided', () {
      final errors = [
        ErrorEntry(
          hash: 'abc',
          error: StateError('bad state'),
          stackTrace: StackTrace.current,
          source: 'flutter',
          firstSeen: DateTime(2026, 3, 17),
          count: 3,
        ),
        ErrorEntry(
          hash: 'def',
          error: ArgumentError('invalid arg'),
          stackTrace: StackTrace.current,
          source: 'zone',
          firstSeen: DateTime(2026, 3, 17),
        ),
      ];

      final report = generateContext(
        errors: errors,
        platform: 'android',
        recentLogs: [],
      );

      expect(report, contains('## Errors'));
      expect(report, contains('**Errors:** 2 unique, 4 total'));
      expect(report, contains('**StateError**'));
      expect(report, contains('3×'));
      expect(report, contains('source: flutter'));
      expect(report, contains('**ArgumentError**'));
      expect(report, contains('1×'));
      expect(report, contains('source: zone'));
    });

    test('includes log table when logs provided', () {
      final logs = [
        LogEntry(
          level: 'error',
          message: 'something broke',
          timestamp: DateTime(2026, 3, 17, 10, 30, 45),
          source: 'flutter',
        ),
        LogEntry(
          level: 'info',
          message: 'all good',
          timestamp: DateTime(2026, 3, 17, 10, 31),
        ),
      ];

      final report = generateContext(
        errors: [],
        platform: 'ios',
        recentLogs: logs,
      );

      expect(report, contains('## Recent Logs (2)'));
      expect(report, contains('| Time | Level | Source | Message |'));
      expect(report, contains('error'));
      expect(report, contains('something broke'));
      expect(report, contains('info'));
      expect(report, contains('all good'));
    });

    test('includes navigation history when route data provided', () {
      final routeHistory = [
        {
          'timestamp': '2026-03-17T10:30:00.000',
          'action': 'push',
          'routeName': '/home',
        },
        {
          'timestamp': '2026-03-17T10:31:00.000',
          'action': 'push',
          'routeName': '/settings',
        },
      ];

      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
        observerInstalled: true,
        routeHistory: routeHistory,
      );

      expect(report, contains('## Navigation History'));
      expect(report, contains('push /home'));
      expect(report, contains('push /settings'));
    });

    test('shows "not installed" message when observer not installed', () {
      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
      );

      expect(report, contains('_MoinsenNavigatorObserver not installed._'));
    });

    test('omits navigation warning when observer installed but no history', () {
      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
        observerInstalled: true,
      );

      expect(
        report,
        isNot(contains('_MoinsenNavigatorObserver not installed._')),
      );
    });

    test('includes screenshot path when provided', () {
      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
        screenshotPath: '/tmp/screenshot.png',
      );

      expect(report, contains('## Screenshot'));
      expect(report, contains('`/tmp/screenshot.png`'));
    });

    test('includes widget tree when provided', () {
      const tree = 'MaterialApp\n  Scaffold\n    Column\n      Text("Hello")';

      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
        widgetTree: tree,
      );

      expect(report, contains('## Widget Tree'));
      expect(report, contains('MaterialApp'));
      expect(report, contains('Text("Hello")'));
    });

    test('condenses widget tree over 50 lines', () {
      final lines = List.generate(80, (i) => 'Widget_$i');
      final tree = lines.join('\n');

      final report = generateContext(
        errors: [],
        platform: 'macos',
        recentLogs: [],
        widgetTree: tree,
      );

      expect(report, contains('## Widget Tree'));
      expect(report, contains('Widget_0'));
      expect(report, contains('Widget_49'));
      expect(report, contains('... (30 more lines)'));
      expect(report, isNot(contains('Widget_50')));
    });

    test('platform and route are shown in header', () {
      final report = generateContext(
        errors: [],
        platform: 'linux',
        recentLogs: [],
        currentRoute: '/dashboard',
      );

      expect(report, contains('**Platform:** linux'));
      expect(report, contains('**Route:** /dashboard'));
    });

    test('truncates long error messages', () {
      final longMessage = 'x' * 200;
      final errors = [
        ErrorEntry(
          hash: 'long',
          error: Exception(longMessage),
          stackTrace: StackTrace.current,
          source: 'zone',
          firstSeen: DateTime(2026, 3, 17),
        ),
      ];

      final report = generateContext(
        errors: errors,
        platform: 'macos',
        recentLogs: [],
      );

      // The full 200-char message should be truncated.
      expect(report, contains('...'));
    });
  });
}
