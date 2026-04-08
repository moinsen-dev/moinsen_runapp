import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/interactive_element.dart';

/// Finds and extracts interactive elements from the Flutter widget tree.
///
/// Traverses the live element tree, filtering for widgets that are
/// interactive, have text content, or carry a `ValueKey<String>`.
/// Each returned element includes bounds, visibility, and
/// hit-test status.
class ElementTreeFinder {
  const ElementTreeFinder(this.config);

  final InteractionConfig config;

  /// Returns all interactive/meaningful elements currently on screen.
  List<InteractiveElement> findInteractiveElements() {
    final elements = <InteractiveElement>[];
    final rootElement = WidgetsBinding.instance.rootElement;

    if (rootElement != null) {
      _visitElement(rootElement, elements);
    }

    return elements;
  }

  void _visitElement(Element element, List<InteractiveElement> result) {
    final widget = element.widget;
    final found = _extractElement(element, widget);

    if (found != null) {
      result.add(found);
    }

    if (config.shouldStopAtType(widget.runtimeType)) {
      return;
    }

    element.visitChildren((child) {
      _visitElement(child, result);
    });
  }

  InteractiveElement? _extractElement(Element element, Widget widget) {
    final renderObject = element.renderObject;
    if (renderObject == null) return null;

    final isInteractive = config.isInteractiveWidgetType(widget.runtimeType);
    final text = config.extractTextFromWidget(widget);
    final keyValue = _extractKeyValue(widget.key);

    // Only include widgets that are interactive, have text, or have a key.
    if (!isInteractive && text == null && keyValue == null) return null;

    // Only include widgets that can actually receive pointer events.
    if (!_canBeHit(renderObject)) return null;

    // Extract diagnostic properties.
    final properties = <String, String>{};
    final diagBuilder = DiagnosticPropertiesBuilder();
    widget.debugFillProperties(diagBuilder);
    for (final p in diagBuilder.properties) {
      if (p.runtimeType != DiagnosticsProperty &&
          p.name != null &&
          p.value != null) {
        properties[p.name!] = p.value.toString();
      }
    }

    // Extract bounds.
    ElementBounds? bounds;
    if (renderObject is RenderBox && renderObject.hasSize) {
      try {
        final offset = renderObject.localToGlobal(Offset.zero);
        final size = renderObject.size;
        bounds = ElementBounds(
          x: offset.dx,
          y: offset.dy,
          width: size.width,
          height: size.height,
        );
      } on Object {
        // Ignore if bounds can't be resolved.
      }
    }

    return InteractiveElement(
      type: widget.runtimeType.toString(),
      key: keyValue,
      text: text,
      bounds: bounds,
      visible: _isElementVisible(renderObject),
      properties: properties,
    );
  }

  static String? _extractKeyValue(Key? key) {
    if (key is ValueKey<String>) return key.value;
    return null;
  }

  /// Checks if the element is currently visible on screen.
  static bool _isElementVisible(RenderObject? renderObject) {
    if (renderObject == null || !renderObject.attached) return false;

    if (renderObject is RenderBox) {
      if (!renderObject.hasSize) return false;

      final size = renderObject.size;
      if (size.width <= 0 || size.height <= 0) return false;

      try {
        final offset = renderObject.localToGlobal(Offset.zero);
        final view = WidgetsBinding.instance.platformDispatcher.views.first;
        final screenSize = view.physicalSize / view.devicePixelRatio;

        return offset.dx + size.width >= 0 &&
            offset.dy + size.height >= 0 &&
            offset.dx < screenSize.width &&
            offset.dy < screenSize.height;
      } on Object {
        return true;
      }
    }

    return true;
  }

  /// Checks if the render object can be hit (receives pointer events).
  static bool _canBeHit(RenderObject renderObject) {
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    if (!renderObject.attached) return false;

    try {
      final hitPoint = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );

      final result = HitTestResult();
      WidgetsBinding.instance.hitTestInView(
        result,
        hitPoint,
        WidgetsBinding.instance.platformDispatcher.views.first.viewId,
      );

      for (final entry in result.path) {
        if (entry.target == renderObject) return true;
      }

      return false;
    } on Object {
      return false;
    }
  }
}
