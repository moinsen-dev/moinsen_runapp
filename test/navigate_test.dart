import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/navigator_observer.dart';
import 'package:moinsen_runapp/src/vm_extensions.dart';

void main() {
  group('handleNavigate', () {
    setUp(MoinsenNavigatorObserver.resetInstance);
    tearDown(MoinsenNavigatorObserver.resetInstance);

    test('returns error when observer not installed', () async {
      final json = await handleNavigate(route: '/home');
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['navigated'], isFalse);
      expect(data['error'], contains('not installed'));
    });

    test('returns error when no route specified and not popping', () async {
      // Install the observer so we get past the first guard.
      MoinsenNavigatorObserver.instance;

      final json = await handleNavigate();
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['navigated'], isFalse);
      expect(data['error'], contains('No route specified'));
    });

    test('returns correct JSON structure for pop action', () async {
      // Install observer but no navigator is attached, so pop returns false.
      MoinsenNavigatorObserver.instance;

      final json = await handleNavigate(pop: true);
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['navigated'], isFalse);
      expect(data['action'], 'pop');
      expect(data['error'], contains('Cannot pop'));
    });

    test('returns correct JSON structure for push action', () async {
      // Install observer but no navigator is attached, so push returns false.
      MoinsenNavigatorObserver.instance;

      final json = await handleNavigate(route: '/settings');
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['navigated'], isFalse);
      expect(data['action'], 'push');
      expect(data['route'], '/settings');
      expect(data['error'], contains('Navigator not available'));
    });
  });

  group('MoinsenNavigatorObserver navigation control', () {
    setUp(MoinsenNavigatorObserver.resetInstance);
    tearDown(MoinsenNavigatorObserver.resetInstance);

    test('pushNamed returns false when navigator is null', () async {
      final observer = MoinsenNavigatorObserver.instance;

      final result = await observer.pushNamed('/home');

      expect(result, isFalse);
    });

    test('pop returns false when navigator is null', () {
      final observer = MoinsenNavigatorObserver.instance;

      final result = observer.pop();

      expect(result, isFalse);
    });

    test('pushNamed delegates to customPushNamed when registered', () async {
      final observer = MoinsenNavigatorObserver.instance;
      String? receivedRoute;
      Object? receivedArgs;

      observer.registerNavigator((route, {arguments}) async {
        receivedRoute = route;
        receivedArgs = arguments;
        return true;
      });

      final result = await observer.pushNamed('/login', arguments: {'id': 1});

      expect(result, isTrue);
      expect(receivedRoute, '/login');
      expect(receivedArgs, {'id': 1});
    });

    test('pushNamed honours customPushNamed return value', () async {
      final observer = MoinsenNavigatorObserver.instance
        ..registerNavigator((route, {arguments}) async => false);

      final result = await observer.pushNamed('/anywhere');

      expect(result, isFalse);
    });

    test('handleNavigate uses customPushNamed handler', () async {
      MoinsenNavigatorObserver.instance.registerNavigator(
        (route, {arguments}) async => true,
      );

      final json = await handleNavigate(route: '/dashboard');
      final data = jsonDecode(json) as Map<String, dynamic>;

      expect(data['navigated'], isTrue);
      expect(data['action'], 'push');
      expect(data['route'], '/dashboard');
      expect(data.containsKey('error'), isFalse);
    });
  });
}
