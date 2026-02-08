import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:moinsen_runapp/src/error_bucket.dart';
import 'package:moinsen_runapp/src/error_entry.dart';

/// A [ChangeNotifier] that bridges the error bucket to UI widgets.
///
/// Defers notifications to the next event loop iteration so they never
/// fire during a build/layout/paint phase. Multiple errors in the same
/// synchronous execution are coalesced into a single notification.
class ErrorObserver extends ChangeNotifier {
  ErrorObserver({required this.bucket});

  /// The underlying error bucket.
  final ErrorBucket bucket;

  int _lastTotalCount = 0;
  int _lastUniqueCount = 0;
  bool _notificationScheduled = false;

  /// Whether any errors have been recorded.
  bool get hasErrors => bucket.uniqueCount > 0;

  /// Total error occurrences across all entries.
  int get totalErrorCount => bucket.totalCount;

  /// Number of unique errors.
  int get uniqueErrorCount => bucket.uniqueCount;

  /// Current list of error entries.
  List<ErrorEntry> get errors => bucket.entries;

  /// Called by the error catcher after each error is added.
  ///
  /// Defers notification to the next event loop iteration to avoid
  /// triggering rebuilds during Flutter's build phase. Multiple
  /// calls within the same synchronous block are coalesced.
  void onErrorAdded() {
    final total = bucket.totalCount;
    final unique = bucket.uniqueCount;
    if (total != _lastTotalCount || unique != _lastUniqueCount) {
      _lastTotalCount = total;
      _lastUniqueCount = unique;
      _scheduleNotification();
    }
  }

  /// Pause error capture. New errors are silently dropped.
  void pause() => bucket.pause();

  /// Resume error capture.
  void resume() => bucket.resume();

  /// Clear all errors and notify listeners.
  void clearErrors() {
    bucket.clear();
    _lastTotalCount = 0;
    _lastUniqueCount = 0;
    notifyListeners();
  }

  void _scheduleNotification() {
    if (_notificationScheduled) return;
    _notificationScheduled = true;

    // Defer to the next event loop iteration. This guarantees
    // we are past any synchronous build/layout/paint phase, and
    // works correctly with Flutter's FakeAsync in tests.
    Timer.run(() {
      _notificationScheduled = false;
      notifyListeners();
    });
  }
}
