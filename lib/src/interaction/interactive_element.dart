/// Data model for an interactive element found in the widget tree.
class InteractiveElement {
  const InteractiveElement({
    required this.type,
    this.key,
    this.text,
    this.bounds,
    this.visible = true,
    this.properties = const {},
  });

  /// Widget runtime type name (e.g. 'ElevatedButton', 'TextField').
  final String type;

  /// Value of the widget's `ValueKey<String>`, if present.
  final String? key;

  /// Extracted text content (from Text, EditableText, etc.).
  final String? text;

  /// Screen-relative bounds: {x, y, width, height}.
  final ElementBounds? bounds;

  /// Whether the element is currently visible on screen.
  final bool visible;

  /// Additional diagnostic properties from the widget.
  final Map<String, String> properties;

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (key != null) 'key': key,
      if (text != null) 'text': text,
      if (bounds != null) 'bounds': bounds!.toJson(),
      'visible': visible,
      if (properties.isNotEmpty) 'properties': properties,
    };
  }
}

/// Screen-relative bounding rectangle.
class ElementBounds {
  const ElementBounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, double> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}
