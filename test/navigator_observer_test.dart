import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/navigator_observer.dart';

Route<void> _route(String name) => MaterialPageRoute<void>(
  settings: RouteSettings(name: name),
  builder: (_) => const SizedBox(),
);

void main() {
  group('MoinsenNavigatorObserver', () {
    late MoinsenNavigatorObserver observer;

    setUp(() {
      MoinsenNavigatorObserver.resetInstance();
      observer = MoinsenNavigatorObserver.instance;
    });

    tearDown(MoinsenNavigatorObserver.resetInstance);

    test('didPush records a route with push action', () {
      observer.didPush(_route('/home'), null);

      expect(observer.history, hasLength(1));
      expect(observer.history.first.action, 'push');
      expect(observer.history.first.routeName, '/home');
    });

    test('didPop records with pop action', () {
      observer.didPop(_route('/home'), null);

      expect(observer.history, hasLength(1));
      expect(observer.history.first.action, 'pop');
      expect(observer.history.first.routeName, '/home');
    });

    test('didReplace records with replace action', () {
      observer.didReplace(
        newRoute: _route('/settings'),
        oldRoute: _route('/home'),
      );

      expect(observer.history, hasLength(1));
      expect(observer.history.first.action, 'replace');
      expect(observer.history.first.routeName, '/settings');
    });

    test('didReplace does nothing when newRoute is null', () {
      observer.didReplace(oldRoute: _route('/home'));

      expect(observer.history, isEmpty);
    });

    test('didRemove records with remove action', () {
      observer.didRemove(_route('/dialog'), null);

      expect(observer.history, hasLength(1));
      expect(observer.history.first.action, 'remove');
      expect(observer.history.first.routeName, '/dialog');
    });

    test('currentRoute returns the latest push/replace route name', () {
      observer
        ..didPush(_route('/home'), null)
        ..didPush(_route('/details'), _route('/home'));

      expect(observer.currentRoute, '/details');
    });

    test('currentRoute returns latest push even after pops', () {
      observer
        ..didPush(_route('/home'), null)
        ..didPush(_route('/details'), _route('/home'))
        ..didPop(_route('/details'), _route('/home'));

      // The last push/replace in history is still '/details' at index 1,
      // but we also have a pop. Walking backwards, pop is found first,
      // then the push for '/details'.
      // Actually the implementation walks backwards and returns first
      // push/replace found, which is the pop's preceding push.
      expect(observer.currentRoute, '/details');
    });

    test('currentRoute returns null when history is empty', () {
      expect(observer.currentRoute, isNull);
    });

    test('history respects capacity limit and evicts oldest', () {
      // Push 25 routes (capacity is 20).
      for (var i = 0; i < 25; i++) {
        observer.didPush(_route('/route-$i'), null);
      }

      expect(observer.history, hasLength(20));
      // First 5 should have been evicted.
      expect(observer.history.first.routeName, '/route-5');
      expect(observer.history.last.routeName, '/route-24');
    });

    test('toJson serialization is correct', () {
      observer.didPush(_route('/home'), null);

      final json = observer.toJson();

      expect(json['currentRoute'], '/home');
      expect(json['observerInstalled'], isTrue);
      expect(json['historyCount'], 1);
      expect(json['history'], isA<List<dynamic>>());

      final history = json['history'] as List<dynamic>;
      expect(history, hasLength(1));

      final entry = history[0] as Map<String, dynamic>;
      expect(entry['action'], 'push');
      expect(entry['routeName'], '/home');
      expect(entry['timestamp'], isA<String>());
    });

    test('isInstalled returns false before first access', () {
      MoinsenNavigatorObserver.resetInstance();

      expect(MoinsenNavigatorObserver.isInstalled, isFalse);
    });

    test('isInstalled returns true after instance access', () {
      MoinsenNavigatorObserver.resetInstance();
      MoinsenNavigatorObserver.instance;

      expect(MoinsenNavigatorObserver.isInstalled, isTrue);
    });

    test('resetInstance clears the singleton', () {
      // instance is already created in setUp.
      expect(MoinsenNavigatorObserver.isInstalled, isTrue);

      MoinsenNavigatorObserver.resetInstance();

      expect(MoinsenNavigatorObserver.isInstalled, isFalse);
    });

    test('clearHistory removes all entries', () {
      observer
        ..didPush(_route('/a'), null)
        ..didPush(_route('/b'), null);
      expect(observer.history, hasLength(2));

      observer.clearHistory();

      expect(observer.history, isEmpty);
      expect(observer.currentRoute, isNull);
    });

    test('route arguments are recorded', () {
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(
          name: '/detail',
          arguments: {'id': 42},
        ),
        builder: (_) => const SizedBox(),
      );
      observer.didPush(route, null);

      expect(observer.history.first.arguments, contains('42'));
    });
  });

  group('RouteRecord', () {
    test('toJson includes arguments only when present', () {
      final withArgs = RouteRecord(
        action: 'push',
        routeName: '/home',
        arguments: '{id: 1}',
        timestamp: DateTime(2025),
      );
      expect(withArgs.toJson(), contains('arguments'));

      final withoutArgs = RouteRecord(
        action: 'push',
        routeName: '/home',
        timestamp: DateTime(2025),
      );
      expect(withoutArgs.toJson().containsKey('arguments'), isFalse);
    });
  });
}
