import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/error_entry.dart';

/// Pre-built error screen variants for release mode.
enum ErrorScreenVariant {
  /// Fun animated character with warm colors and "Oops!" message.
  friendly,

  /// Clean white/dark screen with icon, message, and retry button.
  minimal,

  /// Full-screen CustomPainter illustration with subtle animation.
  illustrated,
}

/// Builder for custom error screens.
typedef ErrorScreenBuilder =
    Widget Function(
      BuildContext context,
      List<ErrorEntry> errors,
    );

/// Configuration for `moinsenRunApp`.
class RunAppConfig {
  const RunAppConfig({
    this.deduplicationWindow = const Duration(seconds: 2),
    this.maxLoggedErrors = 50,
    this.logToFile = false,
    this.logFilePath,
    this.logBufferCapacity = 200,
    this.releaseScreenVariant = ErrorScreenVariant.friendly,
    this.releaseScreenBuilder,
    this.debugScreenBuilder,
    this.screenshotMaxDimension,
    this.monitorHttp = true,
    this.httpBufferCapacity = 100,
  });

  /// Time window for deduplicating identical errors.
  final Duration deduplicationWindow;

  /// Maximum number of unique errors to track before discarding oldest.
  final int maxLoggedErrors;

  /// Maximum number of entries the app-level log buffer retains.
  final int logBufferCapacity;

  /// Whether to write error summaries to a log file.
  final bool logToFile;

  /// Explicit file path for error logs. If null and [logToFile] is true,
  /// the package auto-resolves via `path_provider`.
  final String? logFilePath;

  /// Which pre-built release screen variant to use.
  final ErrorScreenVariant releaseScreenVariant;

  /// Fully custom release error screen. Overrides [releaseScreenVariant].
  final ErrorScreenBuilder? releaseScreenBuilder;

  /// Fully custom debug error screen. Overrides the default developer UI.
  final ErrorScreenBuilder? debugScreenBuilder;

  /// Maximum dimension (in physical pixels) for screenshots.
  ///
  /// If null (the default), no limit is applied.
  final int? screenshotMaxDimension;

  /// Whether to monitor HTTP traffic via `HttpOverrides`.
  ///
  /// When enabled (the default), all `dart:io` HTTP requests are
  /// automatically intercepted and recorded for LLM debugging context.
  final bool monitorHttp;

  /// Maximum number of HTTP requests to retain in the ring buffer.
  final int httpBufferCapacity;
}
