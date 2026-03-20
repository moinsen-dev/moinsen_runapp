import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures the current screen as PNG image bytes.
///
/// Uses the render view's layer tree directly — no [RepaintBoundary]
/// wrapper needed. Returns `null` if capture fails (e.g. headless
/// environment, no render views available).
class ScreenshotService {
  const ScreenshotService._();

  /// Capture the current screen.
  ///
  /// [pixelRatio] controls resolution (1.0 = logical pixels,
  /// 2.0 = 2x, etc.). Defaults to the device's native ratio.
  /// [maxDimension] caps the largest side in physical pixels.
  /// If the captured image would exceed this, the pixel ratio
  /// is reduced proportionally.
  static Future<ScreenshotResult?> capture({
    double? pixelRatio,
    int? maxDimension,
  }) async {
    final binding = WidgetsBinding.instance;

    final renderViews = binding.renderViews.toList();
    if (renderViews.isEmpty) return null;

    final renderView = renderViews.first;
    final size = renderView.size;
    if (size == Size.zero) return null;

    var effectiveRatio =
        pixelRatio ?? renderView.configuration.devicePixelRatio;

    // Cap resolution if maxDimension is specified.
    if (maxDimension != null && maxDimension > 0) {
      final maxSide = size.width > size.height ? size.width : size.height;
      final maxPhysical = maxSide * effectiveRatio;
      if (maxPhysical > maxDimension) {
        effectiveRatio = maxDimension / maxSide;
      }
    }

    // RenderView.layer is protected but there is no public API to capture
    // the scene to an image; direct layer access is the standard approach.
    // ignore: invalid_use_of_protected_member
    final layer = renderView.layer as OffsetLayer?;
    if (layer == null) return null;

    final bounds = Offset.zero & size;

    try {
      final image = await layer.toImage(
        bounds,
        pixelRatio: effectiveRatio,
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData == null) return null;

      return ScreenshotResult(
        bytes: byteData.buffer.asUint8List(),
        width: (size.width * effectiveRatio).round(),
        height: (size.height * effectiveRatio).round(),
      );
    } on Object {
      return null;
    }
  }
}

/// Result of a screenshot capture.
class ScreenshotResult {
  const ScreenshotResult({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final int width;
  final int height;
}
