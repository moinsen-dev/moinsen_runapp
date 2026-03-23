import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/device_info_collector.dart';

void main() {
  group('DeviceInfoCollector', () {
    test('collect returns a map with expected keys', () {
      final info = DeviceInfoCollector.collect();

      expect(info, containsPair('os', isA<String>()));
      expect(info, containsPair('dartVersion', isA<String>()));
      expect(info, containsPair('devicePixelRatio', isA<double>()));
      expect(info, containsPair('physicalWidth', isA<double>()));
      expect(info, containsPair('physicalHeight', isA<double>()));
      expect(info, containsPair('logicalWidth', isA<double>()));
      expect(info, containsPair('logicalHeight', isA<double>()));
      expect(info, containsPair('locale', isA<String>()));
      expect(info, containsPair('textScaleFactor', isA<double>()));
      expect(info, containsPair('platformBrightness', isA<String>()));
    });

    test('collect returns accessibility features', () {
      final info = DeviceInfoCollector.collect();

      expect(
        info,
        containsPair('accessibilityFeatures', isA<Map<String, dynamic>>()),
      );
      final a11y = info['accessibilityFeatures'] as Map<String, dynamic>;
      expect(a11y, containsPair('boldText', isA<bool>()));
      expect(a11y, containsPair('highContrast', isA<bool>()));
      expect(a11y, containsPair('disableAnimations', isA<bool>()));
      expect(a11y, containsPair('reduceMotion', isA<bool>()));
    });

    test('collect returns valid brightness value', () {
      final info = DeviceInfoCollector.collect();
      final brightness = info['platformBrightness'] as String;

      expect(brightness, anyOf('light', 'dark'));
    });

    test('collect returns positive pixel ratio', () {
      final info = DeviceInfoCollector.collect();
      final ratio = info['devicePixelRatio'] as double;

      expect(ratio, greaterThan(0));
    });

    test('logical size is physical size divided by pixel ratio', () {
      final info = DeviceInfoCollector.collect();
      final physW = info['physicalWidth'] as double;
      final physH = info['physicalHeight'] as double;
      final ratio = info['devicePixelRatio'] as double;
      final logW = info['logicalWidth'] as double;
      final logH = info['logicalHeight'] as double;

      if (ratio > 0 && physW > 0) {
        expect(logW, closeTo(physW / ratio, 0.01));
        expect(logH, closeTo(physH / ratio, 0.01));
      }
    });

    test('toJson returns valid JSON-serializable map', () {
      final info = DeviceInfoCollector.collect();

      // All values should be JSON-serializable primitives or maps.
      for (final entry in info.entries) {
        expect(
          entry.value,
          anyOf(
            isA<String>(),
            isA<num>(),
            isA<bool>(),
            isA<Map<String, dynamic>>(),
            isNull,
          ),
          reason: '${entry.key} should be JSON-serializable',
        );
      }
    });
  });
}
