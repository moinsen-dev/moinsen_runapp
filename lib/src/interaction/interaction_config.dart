import 'package:flutter/material.dart';

/// Configuration callbacks for widget interaction and discovery.
///
/// Standard Flutter widgets (TextField, Button, Text, etc.) are supported
/// by default. Use these callbacks to add support for app-specific widgets.
class InteractionConfig {
  const InteractionConfig({
    this.isInteractiveWidget,
    this.shouldStopTraversal,
    this.extractText,
  });

  /// Determines if an app-specific widget type is interactive.
  ///
  /// Called after checking built-in Flutter widgets. Return true for
  /// custom widgets that should appear in the interactive elements list.
  final bool Function(Type type)? isInteractiveWidget;

  /// Determines if traversal should stop at an app-specific widget type.
  ///
  /// Called after checking built-in Flutter widgets. Return true for
  /// widgets whose children should not be traversed.
  final bool Function(Type type)? shouldStopTraversal;

  /// Extracts text from an app-specific widget instance.
  ///
  /// Called after checking built-in Flutter widgets. Return the text
  /// content, or null if not applicable.
  final String? Function(Widget widget)? extractText;

  /// Checks if a widget type is interactive (built-in + custom).
  bool isInteractiveWidgetType(Type type) {
    return _isBuiltInInteractiveWidget(type) ||
        (isInteractiveWidget?.call(type) ?? false);
  }

  /// Whether traversal should stop at the given widget type.
  bool shouldStopAtType(Type type) {
    if (_isBuiltInStopWidget(type)) return true;
    return shouldStopTraversal?.call(type) ?? false;
  }

  /// Extracts text from a widget (built-in + custom).
  String? extractTextFromWidget(Widget widget) {
    return _extractBuiltInText(widget) ?? extractText?.call(widget);
  }

  // -- Built-in Flutter widget support --

  static bool _isBuiltInInteractiveWidget(Type type) {
    return type == Checkbox ||
        type == CheckboxListTile ||
        type == DropdownButton ||
        type == DropdownButtonFormField ||
        type == ElevatedButton ||
        type == FilledButton ||
        type == FloatingActionButton ||
        type == GestureDetector ||
        type == IconButton ||
        type == InkWell ||
        type == OutlinedButton ||
        type == PopupMenuButton ||
        type == Radio ||
        type == RadioListTile ||
        type == Slider ||
        type == Switch ||
        type == SwitchListTile ||
        type == TextButton ||
        type == TextField ||
        type == TextFormField ||
        type == ButtonStyleButton;
  }

  static bool _isBuiltInStopWidget(Type type) {
    // GestureDetector and InkWell can wrap children — don't stop.
    return (type != GestureDetector && type != InkWell) &&
        (_isBuiltInInteractiveWidget(type) || type == Text);
  }

  static String? _extractBuiltInText(Widget widget) {
    if (widget is Text) {
      return widget.data ?? widget.textSpan?.toPlainText();
    }
    if (widget is RichText) {
      return widget.text.toPlainText();
    }
    if (widget is EditableText) {
      return widget.controller.text;
    }
    if (widget is TextField) {
      return widget.controller?.text;
    }
    if (widget is TextFormField) {
      return widget.controller?.text;
    }
    return null;
  }
}
