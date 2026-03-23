import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/state_registry.dart';

void main() {
  group('MoinsenStateRegistry', () {
    late MoinsenStateRegistry registry;

    setUp(() {
      MoinsenStateRegistry.resetInstance();
      registry = MoinsenStateRegistry.instance;
    });

    tearDown(MoinsenStateRegistry.resetInstance);

    test('starts empty', () {
      expect(registry.keys, isEmpty);
      expect(registry.snapshot(), isEmpty);
    });

    test('registers and snapshots a state provider', () {
      registry.register('counter', () => 42);

      final snap = registry.snapshot();
      expect(snap, containsPair('counter', 42));
    });

    test('registers multiple state providers', () {
      registry
        ..register('counter', () => 42)
        ..register('user', () => {'name': 'Uli', 'role': 'admin'});

      final snap = registry.snapshot();
      expect(snap, hasLength(2));
      expect(snap['counter'], 42);
      expect(snap['user'], isA<Map<String, dynamic>>());
    });

    test('unregisters a state provider', () {
      registry
        ..register('counter', () => 42)
        ..unregister('counter');

      expect(registry.keys, isEmpty);
      expect(registry.snapshot(), isEmpty);
    });

    test('unregistering unknown key is a no-op', () {
      registry.unregister('nonexistent');

      expect(registry.keys, isEmpty);
    });

    test('snapshots a specific key', () {
      registry
        ..register('a', () => 1)
        ..register('b', () => 2);

      final snap = registry.snapshotKey('a');
      expect(snap, 1);
    });

    test('snapshotKey returns null for unknown key', () {
      expect(registry.snapshotKey('missing'), isNull);
    });

    test('snapshot function is called lazily', () {
      var callCount = 0;
      registry.register('lazy', () {
        callCount++;
        return 'value';
      });

      expect(callCount, 0);
      registry.snapshot();
      expect(callCount, 1);
      registry.snapshot();
      expect(callCount, 2);
    });

    test('handles throwing snapshot functions gracefully', () {
      registry
        ..register('good', () => 'ok')
        ..register('bad', () => throw StateError('oops'));

      final snap = registry.snapshot();
      expect(snap['good'], 'ok');
      expect(snap['bad'], contains('Bad state'));
    });

    test('replaces existing registration', () {
      registry
        ..register('counter', () => 1)
        ..register('counter', () => 2);

      expect(registry.snapshot()['counter'], 2);
    });

    test('isInstalled returns false before first access', () {
      MoinsenStateRegistry.resetInstance();

      expect(MoinsenStateRegistry.isInstalled, isFalse);
    });

    test('isInstalled returns true after instance access', () {
      MoinsenStateRegistry.resetInstance();
      MoinsenStateRegistry.instance;

      expect(MoinsenStateRegistry.isInstalled, isTrue);
    });

    test('keys returns registered key names', () {
      registry
        ..register('a', () => 1)
        ..register('b', () => 2);

      expect(registry.keys, containsAll(['a', 'b']));
    });

    test('toJson wraps snapshot with states key', () {
      registry.register('cart', () => {'items': 3, 'total': 49.99});

      final json = registry.toJson();

      expect(json['states'], isA<Map<String, dynamic>>());
      expect(json['registeredKeys'], ['cart']);
    });
  });
}
