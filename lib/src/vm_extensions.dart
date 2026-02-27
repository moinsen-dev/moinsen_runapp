import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/prompt_generator.dart';

/// Register VM Service extensions for external tooling access.
///
/// Extensions are prefixed with `ext.moinsen.` and provide structured
/// JSON access to errors, logs, and diagnostics. Only call this once —
/// duplicate registration throws.
void registerMoinsenExtensions({
  required ErrorBucket bucket,
  required ErrorObserver observer,
  required LogBuffer logBuffer,
}) {
  developer.registerExtension(
    'ext.moinsen.getErrors',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetErrors(bucket),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.clearErrors',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleClearErrors(observer),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getInfo',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetInfo(bucket),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getLogs',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetLogs(logBuffer),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getPrompt',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetPrompt(bucket),
    ),
  );
}

/// Handler for ext.moinsen.getErrors — exported for testability.
String handleGetErrors(ErrorBucket bucket) {
  return jsonEncode({
    'errors': bucket.entries.map((e) => e.toJson()).toList(),
    'totalCount': bucket.totalCount,
    'uniqueCount': bucket.uniqueCount,
  });
}

/// Handler for ext.moinsen.clearErrors — exported for testability.
String handleClearErrors(ErrorObserver observer) {
  observer.clearErrors();
  return jsonEncode({'cleared': true});
}

/// Handler for ext.moinsen.getInfo — exported for testability.
String handleGetInfo(ErrorBucket bucket) {
  return jsonEncode({
    'package': 'moinsen_runapp',
    'errorCount': bucket.totalCount,
    'uniqueErrors': bucket.uniqueCount,
    'platform': Platform.operatingSystem,
  });
}

/// Handler for ext.moinsen.getLogs — exported for testability.
String handleGetLogs(LogBuffer logBuffer) {
  return jsonEncode({
    'logs': logBuffer.toJson(),
    'capacity': logBuffer.capacity,
    'size': logBuffer.size,
  });
}

/// Handler for ext.moinsen.getPrompt — exported for testability.
String handleGetPrompt(ErrorBucket bucket) {
  return jsonEncode({
    'prompt': generateBugReport(
      errors: bucket.entries,
      platform: Platform.operatingSystem,
    ),
  });
}
