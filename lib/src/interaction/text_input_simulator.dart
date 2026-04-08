import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/widget_finder.dart';
import 'package:moinsen_runapp/src/interaction/widget_matcher.dart';

/// Simulates text input by directly updating text field controllers.
class TextInputSimulator {
  const TextInputSimulator(this._widgetFinder);

  final WidgetFinder _widgetFinder;

  /// Enters [text] into the text field identified by [matcher].
  ///
  /// Finds the matching element, locates the EditableText in its subtree,
  /// and updates the controller directly.
  Future<void> enterText(
    WidgetMatcher matcher,
    String text,
    InteractionConfig config,
  ) async {
    final element = _widgetFinder.findElementFromRoot(matcher, config);
    if (element == null) {
      throw StateError('No element found matching $matcher');
    }

    // Find EditableText within the matched element's subtree.
    final editableElement = _findEditableText(element);
    if (editableElement == null) {
      throw StateError(
        'No EditableText found in subtree of matched element',
      );
    }

    final editableText = editableElement.widget as EditableText;
    editableText.controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);

    WidgetsBinding.instance.scheduleFrame();
  }

  /// Searches the subtree for an EditableText element.
  Element? _findEditableText(Element root) {
    Element? found;
    void visitor(Element element) {
      if (found != null) return;
      if (element.widget is EditableText) {
        found = element;
      } else {
        element.visitChildren(visitor);
      }
    }

    root.visitChildren(visitor);
    return found;
  }
}
