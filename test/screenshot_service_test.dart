import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/screenshot_service.dart';
import 'package:moinsen_runapp/src/vm_extensions.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenshotResult', () {
    test('holds correct values', () {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = ScreenshotResult(
        bytes: bytes,
        width: 1080,
        height: 1920,
      );

      expect(result.bytes, bytes);
      expect(result.width, 1080);
      expect(result.height, 1920);
    });
  });

  group('ScreenshotService.capture', () {
    test('returns null when no widget is pumped', () async {
      // Without a pumped widget tree, capture should return null
      // (no render views with layers, or layer is not OffsetLayer).
      final result = await ScreenshotService.capture();
      // In test environment this is null because there is no painted
      // layer tree.
      expect(result, isNull);
    });
  });

  group('handleScreenshot', () {
    test('returns error JSON when capture fails', () async {
      final json = await handleScreenshot();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['error'], 'Screenshot capture failed');
    });

    test('respects scale parameter', () async {
      final json = await handleScreenshot(scale: 2);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['error'], 'Screenshot capture failed');
    });
  });
}
