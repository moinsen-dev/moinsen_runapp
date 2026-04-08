import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/widget_matcher.dart';

/// Finds a specific widget in the tree using a [WidgetMatcher].
class WidgetFinder {
  const WidgetFinder(this.config);

  final InteractionConfig config;

  /// Find the first element matching [matcher] and return its center offset.
  ///
  /// For [CoordinatesMatcher], returns the coordinates directly.
  /// Returns `null` if no matching, attached element is found.
  Offset? findElement(WidgetMatcher matcher) {
    if (matcher is CoordinatesMatcher) {
      return matcher.offset;
    }

    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) return null;

    return _searchOffset(rootElement, matcher);
  }

  /// Find the first [Element] matching [matcher] starting from the root.
  ///
  /// Unlike [findElement], this returns the raw Element (needed for
  /// subtree operations like finding EditableText inside a TextField).
  Element? findElementFromRoot(
    WidgetMatcher matcher,
    InteractionConfig cfg,
  ) {
    final rootElement = WidgetsBinding.instance.rootElement;
    if (rootElement == null) return null;
    return _searchElement(rootElement, matcher);
  }

  Offset? _searchOffset(Element element, WidgetMatcher matcher) {
    if (matcher.matches(element.widget, config)) {
      final renderObject = element.renderObject;
      if (renderObject is RenderBox &&
          renderObject.hasSize &&
          renderObject.attached) {
        try {
          return renderObject.localToGlobal(
            renderObject.size.center(Offset.zero),
          );
        } on Object {
          return null;
        }
      }
    }

    Offset? found;
    element.visitChildren((child) {
      found ??= _searchOffset(child, matcher);
    });
    return found;
  }

  Element? _searchElement(Element element, WidgetMatcher matcher) {
    if (matcher.matches(element.widget, config)) {
      return element;
    }

    Element? found;
    element.visitChildren((child) {
      found ??= _searchElement(child, matcher);
    });
    return found;
  }
}
