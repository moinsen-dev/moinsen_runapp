import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:moinsen_runapp/src/config.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_catcher.dart';
import 'package:moinsen_runapp/src/error_file_logger.dart';
import 'package:moinsen_runapp/src/error_logger.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/ui/error_boundary_widget.dart';
import 'package:path_provider/path_provider.dart';

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
  final catcher = ErrorCatcher(
    bucket: bucket,
    observer: observer,
    logger: logger,
    onError: onError,
  );

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

      // 5. Override ErrorWidget.builder for inline widget errors.
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

      // 6. Set up file logger if configured.
      if (config.logToFile) {
        final path =
            config.logFilePath ?? await _resolveLogPath();
        if (path != null) {
          final fileLogger = ErrorFileLogger(filePath: path);
          await fileLogger.init();
        }
      }

      // 7. Execute init callback if provided.
      //    Errors are caught and logged but NEVER prevent app start.
      if (init != null) {
        try {
          await init();
        } on Object catch (error, stack) {
          catcher.handleInitError(error, stack);
        }
      }

      // 8. ALWAYS run the app — regardless of init errors.
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
