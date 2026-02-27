import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_entry.dart';
import 'package:moinsen_runapp/src/error_file_logger.dart';
import 'package:moinsen_runapp/src/error_logger.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

/// Callback for external error reporting (Sentry, Crashlytics, etc.).
typedef ErrorCallback = void Function(Object error, StackTrace stackTrace);

/// Sets up the three-layer error catching:
/// 1. FlutterError.onError → framework errors (build/layout/paint)
/// 2. PlatformDispatcher.onError → uncaught async errors
/// 3. runZonedGuarded → zone-level catch-all
class ErrorCatcher {
  ErrorCatcher({
    required this.bucket,
    required this.observer,
    required this.logger,
    this.fileLogger,
    this.logBuffer,
    this.onError,
  });

  final ErrorBucket bucket;
  final ErrorObserver observer;
  final ErrorLogger logger;
  final ErrorFileLogger? fileLogger;
  final LogBuffer? logBuffer;
  final ErrorCallback? onError;

  /// Set up FlutterError.onError for framework errors.
  void setupFlutterErrorHandler() {
    FlutterError.onError = (details) {
      _handleError(
        details.exception,
        details.stack ?? StackTrace.current,
        'flutter',
        diagnostics: details.toString(),
      );
    };
  }

  /// Set up PlatformDispatcher.onError for uncaught async errors.
  void setupPlatformDispatcher() {
    PlatformDispatcher.instance.onError = (error, stack) {
      _handleError(error, stack, 'platform');
      return true; // Prevent framework default handler.
    };
  }

  /// Run the given [body] inside a guarded zone that catches
  /// any remaining uncaught errors.
  Future<void> runGuarded(Future<void> Function() body) async {
    await runZonedGuarded(body, (error, stack) {
      _handleError(error, stack, 'zone');
    });
  }

  /// Handle an init-phase error.
  void handleInitError(Object error, StackTrace stack) {
    _handleError(error, stack, 'init');
  }

  /// Manually report a caught error through the full error pipeline.
  ///
  /// Use this for errors that are caught by application code (e.g. in
  /// state management, API calls, or background tasks) and would otherwise
  /// not reach the three automatic error layers.
  ///
  /// Returns the [ErrorEntry] if recorded, or `null` if the bucket is paused.
  ErrorEntry? reportError(
    Object error,
    StackTrace stackTrace, {
    String source = 'app',
    String? diagnostics,
  }) {
    return _handleError(error, stackTrace, source, diagnostics: diagnostics);
  }

  ErrorEntry? _handleError(
    Object error,
    StackTrace stack,
    String source, {
    String? diagnostics,
  }) {
    final entry = bucket.add(
      error: error,
      stackTrace: stack,
      source: source,
      diagnostics: diagnostics,
    );

    // Bucket is paused — silently drop the error.
    if (entry == null) return null;

    // Log first occurrence to console.
    logger.log(entry);

    // Feed into ring buffer for VM Service access.
    logBuffer?.add(
      level: 'error',
      message: '${entry.error.runtimeType}: ${entry.label}',
      source: entry.source,
    );

    // Write to file if configured.
    fileLogger?.log(entry);

    // Notify UI.
    observer.onErrorAdded();

    // Forward to external reporter.
    onError?.call(error, stack);

    return entry;
  }
}
