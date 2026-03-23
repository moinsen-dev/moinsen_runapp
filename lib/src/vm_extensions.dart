import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:moinsen_runapp/src/device_info_collector.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/http_monitor.dart';
import 'package:moinsen_runapp/src/lifecycle_observer.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';
import 'package:moinsen_runapp/src/navigator_observer.dart';
import 'package:moinsen_runapp/src/prompt_generator.dart';
import 'package:moinsen_runapp/src/screenshot_service.dart';
import 'package:moinsen_runapp/src/state_registry.dart';

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
    'ext.moinsen.getDeviceInfo',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetDeviceInfo(),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getLifecycle',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetLifecycle(),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getNetwork',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetNetwork(),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.getState',
    (method, params) async {
      final key = params['key'];
      return developer.ServiceExtensionResponse.result(
        handleGetState(key: key),
      );
    },
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
    'device': DeviceInfoCollector.collect(),
    'lifecycle': jsonDecode(handleGetLifecycle()),
    'network': jsonDecode(handleGetNetwork()),
    'state': jsonDecode(handleGetState()),
  });
}

/// Handler for ext.moinsen.getState — exported for testability.
String handleGetState({String? key}) {
  if (!MoinsenStateRegistry.isInstalled) {
    return jsonEncode({'states': <String, dynamic>{}});
  }

  if (key != null && key.isNotEmpty) {
    return jsonEncode({
      'states': {key: MoinsenStateRegistry.instance.snapshotKey(key)},
    });
  }

  return jsonEncode(MoinsenStateRegistry.instance.toJson());
}

/// Handler for ext.moinsen.getNetwork — exported for testability.
String handleGetNetwork() {
  if (!MoinsenHttpMonitor.isInstalled) {
    return jsonEncode({
      'totalCount': 0,
      'errorCount': 0,
      'avgDuration_ms': 0,
      'requests': <dynamic>[],
    });
  }
  return jsonEncode(MoinsenHttpMonitor.instance.toJson());
}

/// Handler for ext.moinsen.getDeviceInfo — exported for testability.
String handleGetDeviceInfo() {
  return jsonEncode(DeviceInfoCollector.collect());
}

/// Handler for ext.moinsen.getLifecycle — exported for testability.
String handleGetLifecycle() {
  if (!MoinsenLifecycleObserver.isInstalled) {
    return jsonEncode({
      'currentState': 'unknown',
      'uptime_ms': 0,
      'history': <dynamic>[],
    });
  }
  return jsonEncode(MoinsenLifecycleObserver.instance.toJson());
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
