import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Directory, File, Platform;

import 'package:moinsen_runapp/src/device_info_collector.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_observer.dart';
import 'package:moinsen_runapp/src/http_monitor.dart';
import 'package:moinsen_runapp/src/interaction/element_tree_finder.dart';
import 'package:moinsen_runapp/src/interaction/gesture_dispatcher.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/scroll_simulator.dart';
import 'package:moinsen_runapp/src/interaction/text_input_simulator.dart';
import 'package:moinsen_runapp/src/interaction/widget_finder.dart';
import 'package:moinsen_runapp/src/interaction/widget_matcher.dart';
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

  // Capability handshake: lets a client (DebugDeck, Claude Code) discover the
  // version + available ext.moinsen.* so it adapts to what this build has.
  developer.registerExtension(
    'ext.moinsen.getCapabilities',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetCapabilities(),
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
    'ext.moinsen.getProjectBrain',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetProjectBrain(),
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

/// Register interaction-related VM Service extensions.
///
/// Adds `ext.moinsen.getInteractiveElements`, `ext.moinsen.tap`,
/// `ext.moinsen.enterText`, and `ext.moinsen.scrollTo`.
/// Only call this when `enableInteraction` is true.
void registerInteractionExtensions({
  required InteractionConfig interactionConfig,
}) {
  final config = interactionConfig;
  final treeFinder = ElementTreeFinder(config);
  final widgetFinder = WidgetFinder(config);
  final gestureDispatcher = GestureDispatcher();
  final textInputSimulator = TextInputSimulator(widgetFinder);
  final scrollSimulator = ScrollSimulator(
    gestureDispatcher,
    widgetFinder,
  );

  developer.registerExtension(
    'ext.moinsen.getInteractiveElements',
    (method, params) async => developer.ServiceExtensionResponse.result(
      handleGetInteractiveElements(treeFinder),
    ),
  );

  developer.registerExtension(
    'ext.moinsen.tap',
    (method, params) async {
      return developer.ServiceExtensionResponse.result(
        await handleTap(
          params,
          gestureDispatcher,
          widgetFinder,
          config,
        ),
      );
    },
  );

  developer.registerExtension(
    'ext.moinsen.enterText',
    (method, params) async {
      return developer.ServiceExtensionResponse.result(
        await handleEnterText(
          params,
          textInputSimulator,
          config,
        ),
      );
    },
  );

  developer.registerExtension(
    'ext.moinsen.scrollTo',
    (method, params) async {
      return developer.ServiceExtensionResponse.result(
        await handleScrollTo(
          params,
          scrollSimulator,
          config,
        ),
      );
    },
  );
}

/// Handler for ext.moinsen.getInteractiveElements.
String handleGetInteractiveElements(ElementTreeFinder treeFinder) {
  final elements = treeFinder.findInteractiveElements();
  return jsonEncode({
    'elements': elements.map((e) => e.toJson()).toList(),
    'count': elements.length,
  });
}

/// Handler for ext.moinsen.tap.
Future<String> handleTap(
  Map<String, String> params,
  GestureDispatcher gestureDispatcher,
  WidgetFinder widgetFinder,
  InteractionConfig config,
) async {
  try {
    final matcher = WidgetMatcher.fromParams(params);
    await gestureDispatcher.tap(matcher, widgetFinder, config);
    return jsonEncode({'success': true});
  } on Object catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// Handler for ext.moinsen.enterText.
Future<String> handleEnterText(
  Map<String, String> params,
  TextInputSimulator textInputSimulator,
  InteractionConfig config,
) async {
  try {
    final input = params['input'] ?? '';
    final matcherParams = Map<String, String>.from(params)..remove('input');
    final matcher = WidgetMatcher.fromParams(matcherParams);
    await textInputSimulator.enterText(matcher, input, config);
    return jsonEncode({'success': true});
  } on Object catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
}

/// Handler for ext.moinsen.scrollTo.
Future<String> handleScrollTo(
  Map<String, String> params,
  ScrollSimulator scrollSimulator,
  InteractionConfig config,
) async {
  try {
    final matcher = WidgetMatcher.fromParams(params);
    await scrollSimulator.scrollUntilVisible(matcher, config);
    return jsonEncode({'success': true});
  } on Object catch (e) {
    return jsonEncode({'success': false, 'error': e.toString()});
  }
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

/// The moinsen_runapp version reported in the capability handshake.
const moinsenRunappVersion = '0.7.4';

/// The `ext.moinsen.*` extensions this build registers (without the prefix).
const moinsenExtensions = <String>[
  'getCapabilities',
  'getInfo',
  'getErrors',
  'clearErrors',
  'getLogs',
  'getPrompt',
  'getState',
  'getNetwork',
  'getRoute',
  'navigate',
  'getLifecycle',
  'getDeviceInfo',
  'getContext',
  'getProjectBrain',
  'getInteractiveElements',
  'tap',
  'enterText',
  'scrollTo',
  'screenshot',
];

/// Handler for ext.moinsen.getCapabilities — the client handshake. Lets a
/// client discover the version + available extensions and adapt instead of
/// probing-by-error. Exported for testability.
String handleGetCapabilities() {
  return jsonEncode({
    'package': 'moinsen_runapp',
    'version': moinsenRunappVersion,
    'protocol': 1,
    'extensions': moinsenExtensions,
    'features': {
      'errors': true,
      'logs': true,
      'prompt': true,
      'state': true,
      'network': true,
      'route': true,
      'navigate': true,
      'lifecycle': true,
      'deviceInfo': true,
      'context': true,
      'projectBrain': true, // best-effort: reachable only for host-run apps
      'interactiveElements': true,
      'interaction': true, // tap / enterText / scrollTo
      'screenshot': true,
    },
  });
}

/// Handler for ext.moinsen.getProjectBrain — the "citizen reads the bus" side
/// of the .moinsen/ convention. Best-effort: looks for `.moinsen/manifest.json`
/// from the process working directory upward (works for a host-run app such as
/// `flutter run` on desktop, where CWD is the repo). For sandboxed apps on a
/// device/emulator the repo is unreachable, so it honestly returns
/// `{available: false}` and DebugDeck remains the .moinsen/ scribe.
/// Exported for testability — [start] overrides the search root in tests.
String handleGetProjectBrain({Directory? start}) {
  try {
    var dir = start ?? Directory.current;
    for (var i = 0; i < 6; i++) {
      final mf = File('${dir.path}/.moinsen/manifest.json');
      if (mf.existsSync()) {
        final manifest = jsonDecode(mf.readAsStringSync());
        return jsonEncode({
          'available': true,
          'path': mf.path,
          'manifest': manifest,
        });
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break; // reached filesystem root
      dir = parent;
    }
  } catch (_) {
    // Unreadable / not JSON / no FS access → fall through to unavailable.
  }
  return jsonEncode({'available': false});
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
