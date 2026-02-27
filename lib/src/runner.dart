import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moinsen_runapp/src/config.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_catcher.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/error_file_logger.dart';
import 'package:moinsen_runapp/src/error_logger.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/ui/error_boundary_widget.dart';
import 'package:moinsen_runapp/src/vm_extensions.dart';
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// Global error reporter
// ---------------------------------------------------------------------------

ErrorCatcher? _globalCatcher;

/// Manually report a caught error through the moinsen_runapp error pipeline.
///
/// Use this for errors that are caught by application code (e.g. in Riverpod
/// providers, API calls, or background tasks) and would otherwise not reach
/// the three automatic error layers (Flutter, Platform, Zone).
///
/// The error passes through the full pipeline: deduplication, console logging,
/// file logging (if configured), UI notification, and the external `onError`
/// callback.
///
/// Returns the [ErrorEntry] if recorded, or `null` if the error system is not
/// yet initialized (i.e. [moinsenRunApp] has not been called) or the error
/// bucket is paused.
///
/// ```dart
/// try {
///   await api.fetchData();
/// } catch (e, stack) {
///   moinsenReportError(e, stack, source: 'api');
///   // handle error locally...
/// }
/// ```
ErrorEntry? moinsenReportError(
  Object error,
  StackTrace stackTrace, {
  String source = 'app',
  String? diagnostics,
}) {
  return _globalCatcher?.reportError(
    error,
    stackTrace,
    source: source,
    diagnostics: diagnostics,
  );
}

/// Reset the global error catcher. Only for use in tests.
@visibleForTesting
void resetGlobalErrorCatcher() {
  _globalCatcher = null;
}

/// Set up a minimal error catcher for testing [moinsenReportError].
///
/// Returns the [ErrorObserver] so tests can verify notifications.
@visibleForTesting
ErrorObserver setupTestErrorCatcher() {
  final bucket = ErrorBucket();
  final observer = ErrorObserver(bucket: bucket);
  final logger = ErrorLogger();
  _globalCatcher = ErrorCatcher(
    bucket: bucket,
    observer: observer,
    logger: logger,
  );
  return observer;
}

// ---------------------------------------------------------------------------

/// Drop-in replacement for `runApp` with three-layer error catching,
/// error deduplication, and beautiful error screens.
///
/// The app **always starts** regardless of errors. Init failures,
/// widget build errors, and uncaught exceptions are caught, logged,
/// and displayed — but never prevent the app from launching.
///
/// ```dart
/// void main() {
///   moinsenRunApp(child: const MyApp());
/// }
/// ```
void moinsenRunApp({
  required Widget child,
  Future<void> Function()? init,
  void Function(Object error, StackTrace stackTrace)? onError,
  RunAppConfig config = const RunAppConfig(),
}) {
  // 1. Create core components (plain Dart — no zone sensitivity).
  final bucket = ErrorBucket(
    deduplicationWindow: config.deduplicationWindow,
    maxEntries: config.maxLoggedErrors,
  );
  final observer = ErrorObserver(bucket: bucket);
  final logger = ErrorLogger();
  final logBuffer = LogBuffer();
  final catcher = ErrorCatcher(
    bucket: bucket,
    observer: observer,
    logger: logger,
    logBuffer: logBuffer,
    onError: onError,
  );

  // Make catcher available for moinsenReportError().
  _globalCatcher = catcher;

  // 2. Run everything inside a guarded zone so that
  //    ensureInitialized() and runApp() share the same zone.
  unawaited(
    catcher.runGuarded(() async {
      // 3. Ensure binding INSIDE the zone — must match runApp().
      WidgetsFlutterBinding.ensureInitialized();

      // 4. Set up error handler layers 1 & 2.
      catcher
        ..setupFlutterErrorHandler()
        ..setupPlatformDispatcher();

      // 5. Register VM Service extensions for CLI/tooling access.
      if (kDebugMode) {
        registerMoinsenExtensions(
          bucket: bucket,
          observer: observer,
          logBuffer: logBuffer,
        );
      }

      // 6. Override ErrorWidget.builder for inline widget errors.
      //    Wrapped in Directionality because this widget can render
      //    anywhere in the tree — including above MaterialApp — where
      //    no Directionality ancestor exists.
      ErrorWidget.builder = (details) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: kDebugMode
                ? const Color(0xFFFF0000)
                : Colors.transparent,
            child: kDebugMode
                ? Text(
                    '${details.exception}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        );
      };

      // 7. Set up file logger if configured.
      if (config.logToFile) {
        final path =
            config.logFilePath ?? await _resolveLogPath();
        if (path != null) {
          final fileLogger = ErrorFileLogger(filePath: path);
          await fileLogger.init();
        }
      }

      // 8. Execute init callback if provided.
      //    Errors are caught and logged but NEVER prevent app start.
      if (init != null) {
        try {
          await init();
        } on Object catch (error, stack) {
          catcher.handleInitError(error, stack);
        }
      }

      // 9. ALWAYS run the app — regardless of init errors.
      runApp(
        ErrorBoundaryWidget(
          observer: observer,
          config: config,
          child: child,
        ),
      );
    }),
  );
}

/// Resolves the log file path using path_provider.
Future<String?> _resolveLogPath() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/moinsen_runapp_errors.log';
  } on Object {
    return null;
  }
}
