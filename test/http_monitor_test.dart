import 'package:flutter_test/flutter_test.dart';
import 'package:moinsen_runapp/src/http_monitor.dart';

void main() {
  group('MoinsenHttpMonitor', () {
    late MoinsenHttpMonitor monitor;

    setUp(() {
      MoinsenHttpMonitor.resetInstance();
      monitor = MoinsenHttpMonitor.instance;
    });

    tearDown(MoinsenHttpMonitor.resetInstance);

    test('starts empty', () {
      expect(monitor.requests, isEmpty);
      expect(monitor.totalCount, 0);
      expect(monitor.errorCount, 0);
    });

    test('records an HTTP request', () {
      monitor.record(
        method: 'GET',
        url: 'https://api.example.com/users',
        statusCode: 200,
        duration: const Duration(milliseconds: 150),
      );

      expect(monitor.requests, hasLength(1));
      expect(monitor.requests.first.method, 'GET');
      expect(monitor.requests.first.url, 'https://api.example.com/users');
      expect(monitor.requests.first.statusCode, 200);
      expect(monitor.requests.first.durationMs, 150);
      expect(monitor.totalCount, 1);
      expect(monitor.errorCount, 0);
    });

    test('records failed requests', () {
      monitor.record(
        method: 'POST',
        url: 'https://api.example.com/auth',
        statusCode: 500,
        duration: const Duration(milliseconds: 300),
        error: 'Internal Server Error',
      );

      expect(monitor.requests, hasLength(1));
      expect(monitor.requests.first.statusCode, 500);
      expect(monitor.requests.first.error, 'Internal Server Error');
      expect(monitor.errorCount, 1);
    });

    test('counts errors for 4xx and 5xx status codes', () {
      monitor
        ..record(
          method: 'GET',
          url: 'https://a.com/ok',
          statusCode: 200,
          duration: Duration.zero,
        )
        ..record(
          method: 'GET',
          url: 'https://a.com/notfound',
          statusCode: 404,
          duration: Duration.zero,
        )
        ..record(
          method: 'GET',
          url: 'https://a.com/error',
          statusCode: 503,
          duration: Duration.zero,
        );

      expect(monitor.totalCount, 3);
      expect(monitor.errorCount, 2);
    });

    test('counts connection errors without status code', () {
      monitor.record(
        method: 'GET',
        url: 'https://a.com/timeout',
        duration: const Duration(seconds: 30),
        error: 'Connection timed out',
      );

      expect(monitor.errorCount, 1);
      expect(monitor.requests.first.statusCode, isNull);
    });

    test('respects capacity limit', () {
      for (var i = 0; i < 120; i++) {
        monitor.record(
          method: 'GET',
          url: 'https://a.com/$i',
          statusCode: 200,
          duration: Duration.zero,
        );
      }

      expect(monitor.requests, hasLength(100));
      // Oldest should be evicted.
      expect(monitor.requests.first.url, 'https://a.com/20');
    });

    test('custom capacity', () {
      MoinsenHttpMonitor.resetInstance();
      final small = MoinsenHttpMonitor.instanceWithCapacity(10);

      for (var i = 0; i < 15; i++) {
        small.record(
          method: 'GET',
          url: 'https://a.com/$i',
          statusCode: 200,
          duration: Duration.zero,
        );
      }

      expect(small.requests, hasLength(10));
      expect(small.requests.first.url, 'https://a.com/5');
    });

    test('calculates average duration', () {
      monitor
        ..record(
          method: 'GET',
          url: 'https://a.com/1',
          statusCode: 200,
          duration: const Duration(milliseconds: 100),
        )
        ..record(
          method: 'GET',
          url: 'https://a.com/2',
          statusCode: 200,
          duration: const Duration(milliseconds: 300),
        );

      expect(monitor.avgDurationMs, 200);
    });

    test('average duration is 0 when empty', () {
      expect(monitor.avgDurationMs, 0);
    });

    test('isInstalled returns false before first access', () {
      MoinsenHttpMonitor.resetInstance();

      expect(MoinsenHttpMonitor.isInstalled, isFalse);
    });

    test('toJson returns expected structure', () {
      monitor.record(
        method: 'GET',
        url: 'https://api.example.com/data',
        statusCode: 200,
        duration: const Duration(milliseconds: 42),
        requestSize: 0,
        responseSize: 1024,
      );

      final json = monitor.toJson();

      expect(json['totalCount'], 1);
      expect(json['errorCount'], 0);
      expect(json['avgDuration_ms'], 42);
      expect(json['requests'], isA<List<dynamic>>());

      final req =
          (json['requests'] as List<dynamic>).first as Map<String, dynamic>;
      expect(req['method'], 'GET');
      expect(req['url'], 'https://api.example.com/data');
      expect(req['statusCode'], 200);
      expect(req['duration_ms'], 42);
      expect(req['responseSize'], 1024);
    });

    test('sanitizes sensitive headers', () {
      monitor.record(
        method: 'POST',
        url: 'https://a.com/login',
        statusCode: 200,
        duration: Duration.zero,
        requestHeaders: {
          'Authorization': 'Bearer secret123',
          'Content-Type': 'application/json',
          'Cookie': 'session=abc',
        },
        responseHeaders: {
          'Set-Cookie': 'token=xyz',
          'Content-Type': 'application/json',
        },
      );

      final req = monitor.requests.first;
      expect(req.requestHeaders?['Authorization'], '[REDACTED]');
      expect(req.requestHeaders?['Cookie'], '[REDACTED]');
      expect(req.requestHeaders?['Content-Type'], 'application/json');
      expect(req.responseHeaders?['Set-Cookie'], '[REDACTED]');
      expect(
        req.responseHeaders?['Content-Type'],
        'application/json',
      );
    });
  });

  group('HttpRecord', () {
    test('toJson serialization', () {
      final record = HttpRecord(
        method: 'POST',
        url: 'https://api.com/data',
        statusCode: 201,
        durationMs: 55,
        timestamp: DateTime(2025),
        requestSize: 100,
        responseSize: 200,
      );

      final json = record.toJson();

      expect(json['method'], 'POST');
      expect(json['url'], 'https://api.com/data');
      expect(json['statusCode'], 201);
      expect(json['duration_ms'], 55);
      expect(json['requestSize'], 100);
      expect(json['responseSize'], 200);
      expect(json['timestamp'], isA<String>());
    });

    test('toJson omits null optional fields', () {
      final record = HttpRecord(
        method: 'GET',
        url: 'https://a.com',
        durationMs: 10,
        timestamp: DateTime(2025),
      );

      final json = record.toJson();

      expect(json.containsKey('statusCode'), isFalse);
      expect(json.containsKey('error'), isFalse);
      expect(json.containsKey('requestSize'), isFalse);
      expect(json.containsKey('requestHeaders'), isFalse);
    });

    test('isError returns true for 4xx and 5xx', () {
      expect(
        HttpRecord(
          method: 'GET',
          url: '',
          statusCode: 404,
          durationMs: 0,
          timestamp: DateTime(2025),
        ).isError,
        isTrue,
      );
      expect(
        HttpRecord(
          method: 'GET',
          url: '',
          statusCode: 200,
          durationMs: 0,
          timestamp: DateTime(2025),
        ).isError,
        isFalse,
      );
    });

    test('isError returns true when error is present', () {
      expect(
        HttpRecord(
          method: 'GET',
          url: '',
          durationMs: 0,
          timestamp: DateTime(2025),
          error: 'timeout',
        ).isError,
        isTrue,
      );
    });
  });
}
