import 'dart:ui' show AppLifecycleState;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/lifecycle_observer.dart';

void main() {
  group('MoinsenLifecycleObserver', () {
    late MoinsenLifecycleObserver observer;

    setUp(() {
      MoinsenLifecycleObserver.resetInstance();
      observer = MoinsenLifecycleObserver.instance;
    });

    tearDown(MoinsenLifecycleObserver.resetInstance);

    test('initial state is resumed', () {
      expect(observer.currentState, AppLifecycleState.resumed);
    });

    test('records lifecycle transitions', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);

      expect(observer.history, hasLength(1));
      expect(observer.history.first.state, AppLifecycleState.inactive);
      expect(
        observer.history.first.previousState,
        AppLifecycleState.resumed,
      );
    });

    test('tracks current state after transitions', () {
      observer
        ..didChangeAppLifecycleState(AppLifecycleState.inactive)
        ..didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(observer.currentState, AppLifecycleState.paused);
      expect(observer.history, hasLength(2));
    });

    test('history respects capacity limit', () {
      // Default capacity is 50.
      for (var i = 0; i < 60; i++) {
        final state = i.isEven
            ? AppLifecycleState.paused
            : AppLifecycleState.resumed;
        observer.didChangeAppLifecycleState(state);
      }

      expect(observer.history, hasLength(50));
    });

    test('isInstalled returns false before first access', () {
      MoinsenLifecycleObserver.resetInstance();

      expect(MoinsenLifecycleObserver.isInstalled, isFalse);
    });

    test('isInstalled returns true after instance access', () {
      MoinsenLifecycleObserver.resetInstance();
      MoinsenLifecycleObserver.instance;

      expect(MoinsenLifecycleObserver.isInstalled, isTrue);
    });

    test('toJson returns expected structure', () {
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      final json = observer.toJson();

      expect(json['currentState'], 'paused');
      expect(json['history'], isA<List<dynamic>>());
      expect(json['history'], hasLength(1));

      final entry =
          (json['history'] as List<dynamic>).first as Map<String, dynamic>;
      expect(entry['state'], 'paused');
      expect(entry['previousState'], 'resumed');
      expect(entry['timestamp'], isA<String>());
    });

    test('uptime_ms is present and non-negative', () {
      final json = observer.toJson();

      expect(json['uptime_ms'], isA<int>());
      expect(json['uptime_ms'] as int, greaterThanOrEqualTo(0));
    });

    test('ignores duplicate consecutive states', () {
      observer
        ..didChangeAppLifecycleState(AppLifecycleState.paused)
        ..didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(observer.history, hasLength(1));
    });
  });

  group('LifecycleRecord', () {
    test('toJson serialization', () {
      final record = LifecycleRecord(
        state: AppLifecycleState.paused,
        previousState: AppLifecycleState.resumed,
        timestamp: DateTime(2025),
      );

      final json = record.toJson();

      expect(json['state'], 'paused');
      expect(json['previousState'], 'resumed');
      expect(json['timestamp'], isA<String>());
    });
  });
}
