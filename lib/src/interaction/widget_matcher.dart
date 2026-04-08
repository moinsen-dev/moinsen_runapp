import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';

/// Strategies for matching widgets in the Flutter widget tree.
///
/// Precedence when multiple params are present:
/// coordinates (x & y) > key > text > type.
sealed class WidgetMatcher {
  const WidgetMatcher();

  /// Whether the given [widget] matches this matcher's criteria.
  bool matches(Widget widget, InteractionConfig config);

  /// Creates a matcher from VM service extension params.
  ///
  /// All values are strings because `dart:developer.registerExtension`
  /// passes `Map<String, String>`.
  static WidgetMatcher fromParams(Map<String, String> params) {
    if (params.containsKey('x') && params.containsKey('y')) {
      return CoordinatesMatcher(
        double.parse(params['x']!),
        double.parse(params['y']!),
      );
    } else if (params.containsKey('key')) {
      return KeyMatcher(params['key']!);
    } else if (params.containsKey('text')) {
      return TextMatcher(params['text']!);
    } else if (params.containsKey('type')) {
      return TypeStringMatcher(params['type']!);
    } else {
      throw ArgumentError(
        'Params must contain "x"+"y", "key", "text", or "type"',
      );
    }
  }
}

/// Matches by screen coordinates. Does not search the widget tree —
/// used as a fast path for direct coordinate-based interaction.
class CoordinatesMatcher extends WidgetMatcher {
  const CoordinatesMatcher(this.x, this.y);

  final double x;
  final double y;

  Offset get offset => Offset(x, y);

  @override
  bool matches(Widget widget, InteractionConfig config) => false;
}

/// Matches widgets by their `ValueKey<String>` value.
class KeyMatcher extends WidgetMatcher {
  const KeyMatcher(this.keyValue);

  final String keyValue;

  @override
  bool matches(Widget widget, InteractionConfig config) {
    final key = widget.key;
    return key is ValueKey<String> && key.value == keyValue;
  }
}

/// Matches widgets by their extracted text content.
class TextMatcher extends WidgetMatcher {
  const TextMatcher(this.text);

  final String text;

  @override
  bool matches(Widget widget, InteractionConfig config) {
    return config.extractTextFromWidget(widget) == text;
  }
}

/// Matches widgets by their runtime type name as a string.
class TypeStringMatcher extends WidgetMatcher {
  const TypeStringMatcher(this.typeName);

  final String typeName;

  @override
  bool matches(Widget widget, InteractionConfig config) {
    return widget.runtimeType.toString() == typeName;
  }
}
