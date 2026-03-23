import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

/// Collects device and environment information for LLM context.
///
/// All data is read live from [PlatformDispatcher] and [Platform] —
/// no state is stored. This gives an LLM the environmental context
/// it needs to diagnose layout bugs, accessibility issues, and
/// platform-specific behavior.
class DeviceInfoCollector {
  DeviceInfoCollector._();

  /// Collect current device and environment information.
  ///
  /// Returns a JSON-serializable map with screen dimensions,
  /// pixel ratio, locale, brightness, accessibility features,
  /// and platform details.
  static Map<String, dynamic> collect() {
    final dispatcher = PlatformDispatcher.instance;
    final physicalSize = dispatcher.views.firstOrNull?.physicalSize;
    final ratio = dispatcher.views.firstOrNull?.devicePixelRatio ?? 1.0;
    final physW = physicalSize?.width ?? 0.0;
    final physH = physicalSize?.height ?? 0.0;
    final a11y = dispatcher.accessibilityFeatures;

    return {
      'os': Platform.operatingSystem,
      'osVersion': Platform.operatingSystemVersion,
      'dartVersion': Platform.version.split(' ').first,
      'devicePixelRatio': ratio,
      'physicalWidth': physW,
      'physicalHeight': physH,
      'logicalWidth': ratio > 0 ? physW / ratio : 0.0,
      'logicalHeight': ratio > 0 ? physH / ratio : 0.0,
      'locale': dispatcher.locale.toLanguageTag(),
      'textScaleFactor': dispatcher.textScaleFactor,
      'platformBrightness':
          dispatcher.platformBrightness.name, // 'light' or 'dark'
      'accessibilityFeatures': {
        'boldText': a11y.boldText,
        'highContrast': a11y.highContrast,
        'disableAnimations': a11y.disableAnimations,
        'reduceMotion': a11y.reduceMotion,
      },
    };
  }
}
