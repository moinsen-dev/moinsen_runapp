import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/log_buffer.dart';

void main() {
  group('LogBuffer', () {
    late LogBuffer buffer;

    setUp(() {
      buffer = LogBuffer(capacity: 3);
    });

    test('starts empty', () {
      expect(buffer.size, 0);
      expect(buffer.capacity, 3);
      expect(buffer.entries, isEmpty);
    });

    test('adds entries and preserves order', () {
      buffer
        ..add(level: 'info', message: 'first')
        ..add(level: 'error', message: 'second');

      expect(buffer.size, 2);
      expect(buffer.entries[0].message, 'first');
      expect(buffer.entries[1].message, 'second');
    });

    test('evicts oldest when capacity exceeded', () {
      buffer
        ..add(level: 'info', message: 'a')
        ..add(level: 'info', message: 'b')
        ..add(level: 'info', message: 'c')
        ..add(level: 'info', message: 'd');

      expect(buffer.size, 3);
      expect(buffer.entries[0].message, 'b');
      expect(buffer.entries[1].message, 'c');
      expect(buffer.entries[2].message, 'd');
    });

    test('clear removes all entries', () {
      buffer
        ..add(level: 'info', message: 'a')
        ..add(level: 'info', message: 'b')
        ..clear();

      expect(buffer.size, 0);
      expect(buffer.entries, isEmpty);
    });

    test('toJson serializes all entries', () {
      buffer.add(level: 'error', message: 'boom', source: 'flutter');

      final json = buffer.toJson();
      expect(json, hasLength(1));
      expect(json[0]['level'], 'error');
      expect(json[0]['message'], 'boom');
      expect(json[0]['source'], 'flutter');
      expect(json[0]['timestamp'], isA<String>());
    });

    test('entry stores level, message, source, and timestamp', () {
      buffer.add(level: 'warning', message: 'test', source: 'zone');

      final entry = buffer.entries.first;
      expect(entry.level, 'warning');
      expect(entry.message, 'test');
      expect(entry.source, 'zone');
      expect(entry.timestamp, isA<DateTime>());
    });

    test('default capacity is 200', () {
      final defaultBuffer = LogBuffer();
      expect(defaultBuffer.capacity, 200);
    });
  });
}
