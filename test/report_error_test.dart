import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/moinsen_runapp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('moinsenReportError (top-level)', () {
    test('returns null when not initialized', () {
      // Reset to ensure clean state.
      resetGlobalErrorCatcher();

      final entry = moinsenReportError(
        StateError('no catcher'),
        StackTrace.current,
      );

      expect(entry, isNull);
    });

    test('reports error when initialized', () {
      // Use the test helper to set up a catcher.
      final observer = setupTestErrorCatcher();

      final entry = moinsenReportError(
        StateError('test error'),
        StackTrace.current,
        source: 'provider',
      );

      expect(entry, isNotNull);
      expect(entry!.source, 'provider');
      expect(observer.hasErrors, isTrue);

      resetGlobalErrorCatcher();
    });

    test('default source is "app"', () {
      setupTestErrorCatcher();

      final entry = moinsenReportError(
        StateError('default source'),
        StackTrace.current,
      );

      expect(entry, isNotNull);
      expect(entry!.source, 'app');

      resetGlobalErrorCatcher();
    });

    test('passes diagnostics through', () {
      setupTestErrorCatcher();

      final entry = moinsenReportError(
        StateError('diag test'),
        StackTrace.current,
        source: 'riverpod',
        diagnostics: 'FeedNotifier build() failed',
      );

      expect(entry, isNotNull);
      expect(entry!.diagnostics, 'FeedNotifier build() failed');

      resetGlobalErrorCatcher();
    });
  });
}
