import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/gesture_dispatcher.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/widget_finder.dart';
import 'package:moinsen_runapp/src/interaction/widget_matcher.dart';

/// Scrolls until a target widget becomes visible and hittable.
class ScrollSimulator {
  const ScrollSimulator(this._gestureDispatcher, this._widgetFinder);

  final GestureDispatcher _gestureDispatcher;
  final WidgetFinder _widgetFinder;

  static const _delta = 64.0;
  static const _maxScrolls = 50;

  /// Scrolls the first [Scrollable] in the tree until the widget matching
  /// [matcher] is visible and hittable.
  Future<void> scrollUntilVisible(
    WidgetMatcher matcher,
    InteractionConfig config,
  ) async {
    // Find the first Scrollable.
    final scrollableElement = _findScrollable();
    if (scrollableElement == null) {
      throw StateError('No Scrollable widget found in the tree');
    }

    final scrollableWidget = scrollableElement.widget as Scrollable;
    final moveStep = switch (scrollableWidget.axisDirection) {
      AxisDirection.up => const Offset(0, _delta),
      AxisDirection.down => const Offset(0, -_delta),
      AxisDirection.left => const Offset(_delta, 0),
      AxisDirection.right => const Offset(-_delta, 0),
    };

    for (var i = 0; i < _maxScrolls; i++) {
      // Check if the target is already visible and hittable.
      final offset = _widgetFinder.findElement(matcher);
      if (offset != null) return;

      // Drag the scrollable.
      final renderObject = scrollableElement.renderObject;
      if (renderObject is! RenderBox || !renderObject.hasSize) {
        throw StateError('Scrollable does not have a RenderBox with size');
      }

      final center = renderObject.localToGlobal(
        renderObject.size.center(Offset.zero),
      );
      await _gestureDispatcher.drag(center, center + moveStep);
    }

    throw StateError(
      'Widget not found after $_maxScrolls scroll attempts',
    );
  }

  Element? _findScrollable() {
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return null;

    Element? found;
    void visitor(Element element) {
      if (found != null) return;
      if (element.widget is Scrollable) {
        found = element;
      } else {
        element.visitChildren(visitor);
      }
    }

    visitor(root);
    return found;
  }
}
