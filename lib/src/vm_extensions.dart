import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/navigator_observer.dart';
import 'package:moinsen_runapp/src/prompt_generator.dart';
import 'package:moinsen_runapp/src/screenshot_service.dart';

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
      handleGetPrompt(bucket, logBuffer),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getRoute',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetRoute(),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.navigate',
    (method, params) async {
      final route = params['route'];
      final pop = params['pop'] == 'true';
      return developer.ServiceExtensionResponse.result(
        await handleNavigate(route: route, pop: pop),
      );
    },
  );

  developer.registerExtension(
    'ext.moinsen.getContext',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetContext(bucket, logBuffer),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.screenshot',
    (method, params) async {
      final scale = double.tryParse(params['scale'] ?? '') ?? 0;
      return developer.ServiceExtensionResponse.result(
        await handleScreenshot(scale: scale),
      );
    },
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
String handleGetPrompt(ErrorBucket bucket, LogBuffer logBuffer) {
  return jsonEncode({
    'prompt': generateEnhancedReport(
      errors: bucket.entries,
      platform: Platform.operatingSystem,
      recentLogs: logBuffer.toJson(),
      currentRoute: MoinsenNavigatorObserver.isInstalled
          ? MoinsenNavigatorObserver.instance.currentRoute
          : null,
      observerInstalled: MoinsenNavigatorObserver.isInstalled,
      routeHistory: MoinsenNavigatorObserver.isInstalled
          ? MoinsenNavigatorObserver.instance.history
                .map((r) => r.toJson())
                .toList()
          : const [],
    ),
  });
}

/// Handler for ext.moinsen.getRoute — exported for testability.
String handleGetRoute() {
  if (!MoinsenNavigatorObserver.isInstalled) {
    return jsonEncode({
      'currentRoute': null,
      'observerInstalled': false,
      'history': <dynamic>[],
    });
  }
  return jsonEncode(MoinsenNavigatorObserver.instance.toJson());
}

/// Handler for ext.moinsen.navigate — exported for testability.
Future<String> handleNavigate({String? route, bool pop = false}) async {
  if (!MoinsenNavigatorObserver.isInstalled) {
    return jsonEncode({
      'navigated': false,
      'error': 'MoinsenNavigatorObserver not installed',
    });
  }

  final observer = MoinsenNavigatorObserver.instance;

  if (pop) {
    final success = observer.pop();
    return jsonEncode({
      'navigated': success,
      'action': 'pop',
      if (!success) 'error': 'Cannot pop (no navigator or at root)',
    });
  }

  if (route == null || route.isEmpty) {
    return jsonEncode({
      'navigated': false,
      'error': 'No route specified',
    });
  }

  final success = await observer.pushNamed(route);
  return jsonEncode({
    'navigated': success,
    'action': 'push',
    'route': route,
    if (!success) 'error': 'Navigator not available',
  });
}

/// Handler for ext.moinsen.getContext — exported for testability.
String handleGetContext(ErrorBucket bucket, LogBuffer logBuffer) {
  final routeData = handleGetRoute();
  return jsonEncode({
    'errors': bucket.entries.map((e) => e.toJson()).toList(),
    'totalErrorCount': bucket.totalCount,
    'uniqueErrorCount': bucket.uniqueCount,
    'logs': logBuffer.toJson(),
    'logCount': logBuffer.size,
    'route': jsonDecode(routeData),
    'platform': Platform.operatingSystem,
  });
}

/// Handler for ext.moinsen.screenshot — exported for testability.
Future<String> handleScreenshot({double scale = 0}) async {
  final result = await ScreenshotService.capture(
    pixelRatio: scale > 0 ? scale : null,
  );
  if (result == null) {
    return jsonEncode({'error': 'Screenshot capture failed'});
  }
  return jsonEncode({
    'screenshot': base64Encode(result.bytes),
    'width': result.width,
    'height': result.height,
  });
}
