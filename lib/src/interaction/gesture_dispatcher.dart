import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:moinsen_runapp/src/interaction/interaction_config.dart';
import 'package:moinsen_runapp/src/interaction/widget_finder.dart';
import 'package:moinsen_runapp/src/interaction/widget_matcher.dart';

/// Dispatches gesture events to simulate user interactions.
///
/// Uses `GestureBinding.instance.handlePointerEvent` — works with
/// any Flutter binding (no custom subclass required).
class GestureDispatcher {
  static const _kMaxDelta = 40.0;
  static const _kDelay = Duration(milliseconds: 10);

  int _nextPointerId = 1;

  /// Simulates a tap on the element matching [matcher].
  ///
  /// For [CoordinatesMatcher], taps directly at the coordinates
  /// without searching the widget tree (fast path).
  Future<void> tap(
    WidgetMatcher matcher,
    WidgetFinder widgetFinder,
    InteractionConfig config,
  ) async {
    final offset = widgetFinder.findElement(matcher);
    if (offset == null) {
      throw StateError('No element found matching $matcher');
    }
    await _dispatchTapAt(offset);
  }

  /// Simulates a drag gesture from [from] to [to].
  Future<void> drag(Offset from, Offset to) async {
    final pointerId = _nextPointerId++;

    final delta = to - from;
    final distance = delta.distance;
    final stepCount = (distance / _kMaxDelta)
        .ceil()
        .clamp(1, double.infinity)
        .toInt();

    final moveRecords = <List<PointerEvent>>[];
    for (var i = 1; i <= stepCount; i++) {
      final t = i / stepCount;
      final position = Offset.lerp(from, to, t)!;
      final previousPosition = i == 1
          ? from
          : Offset.lerp(from, to, (i - 1) / stepCount)!;
      final stepDelta = position - previousPosition;

      moveRecords.add([
        PointerMoveEvent(
          pointer: pointerId,
          position: position,
          delta: stepDelta,
        ),
      ]);
    }

    final records = [
      [
        PointerAddedEvent(position: from),
        PointerDownEvent(pointer: pointerId, position: from),
      ],
      ...moveRecords,
      [PointerUpEvent(pointer: pointerId, position: to)],
    ];

    await _handlePointerEventRecord(records);
  }

  Future<void> _dispatchTapAt(Offset position) async {
    final pointerId = _nextPointerId++;

    final records = [
      [
        PointerAddedEvent(position: position),
        PointerDownEvent(pointer: pointerId, position: position),
      ],
      [PointerUpEvent(pointer: pointerId, position: position)],
    ];

    await _handlePointerEventRecord(records);
  }

  Future<void> _handlePointerEventRecord(
    List<List<PointerEvent>> records,
  ) async {
    for (final record in records) {
      record.forEach(GestureBinding.instance.handlePointerEvent);
      WidgetsBinding.instance.scheduleFrame();
      await Future<void>.delayed(_kDelay);
    }
  }
}
