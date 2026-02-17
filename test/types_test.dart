import 'package:flutter_test/flutter_test.dart';
import 'package:omnipulse_flutter/src/types.dart';

void main() {
  group('OmniPulseConfig', () {
    test('required fields', () {
      const config = OmniPulseConfig(
        apiUrl: 'http://localhost:8080',
        ingestKey: 'test-key',
        appName: 'MyApp',
      );

      expect(config.apiUrl, equals('http://localhost:8080'));
      expect(config.ingestKey, equals('test-key'));
      expect(config.appName, equals('MyApp'));
    });

    test('defaults', () {
      const config = OmniPulseConfig(
        apiUrl: 'http://localhost',
        ingestKey: 'key',
        appName: 'app',
      );

      expect(config.environment, equals('production'));
      expect(config.debug, isFalse);
      expect(config.batchSize, equals(50));
      expect(config.flushIntervalSeconds, equals(10));
      expect(config.appVersion, isNull);
    });

    test('custom values', () {
      const config = OmniPulseConfig(
        apiUrl: 'http://localhost',
        ingestKey: 'key',
        appName: 'app',
        appVersion: '3.0.0',
        environment: 'staging',
        debug: true,
        batchSize: 25,
        flushIntervalSeconds: 3,
      );

      expect(config.appVersion, equals('3.0.0'));
      expect(config.environment, equals('staging'));
      expect(config.debug, isTrue);
      expect(config.batchSize, equals(25));
    });
  });

  group('LogLevel', () {
    test('all levels exist', () {
      expect(LogLevel.values.length, equals(5));
    });

    test('level names', () {
      expect(LogLevel.debug.name, equals('debug'));
      expect(LogLevel.info.name, equals('info'));
      expect(LogLevel.warn.name, equals('warn'));
      expect(LogLevel.error.name, equals('error'));
      expect(LogLevel.fatal.name, equals('fatal'));
    });
  });

  group('LogEntry', () {
    test('toJson with required fields only', () {
      final entry = LogEntry(
        timestamp: DateTime.utc(2025, 6, 15, 12, 0, 0),
        level: LogLevel.info,
        message: 'hello',
      );

      final json = entry.toJson();

      expect(json['level'], equals('info'));
      expect(json['message'], equals('hello'));
      expect(json['timestamp'], contains('2025-06-15'));
      expect(json.containsKey('service_name'), isFalse);
      expect(json.containsKey('tags'), isFalse);
    });

    test('toJson includes all optional fields', () {
      final entry = LogEntry(
        timestamp: DateTime.utc(2025),
        level: LogLevel.error,
        message: 'err',
        serviceName: 'api',
        tags: {'code': 500},
        traceId: 'tr1',
        spanId: 'sp1',
      );

      final json = entry.toJson();

      expect(json['service_name'], equals('api'));
      expect(json['tags']['code'], equals(500));
      expect(json['trace_id'], equals('tr1'));
      expect(json['span_id'], equals('sp1'));
    });
  });

  group('ErrorEvent', () {
    test('toJson with required fields', () {
      final event = ErrorEvent(
        timestamp: DateTime.utc(2025),
        message: 'NullPointerException',
      );

      final json = event.toJson();

      expect(json['message'], equals('NullPointerException'));
      expect(json.containsKey('stack_trace'), isFalse);
    });

    test('toJson with all fields', () {
      final event = ErrorEvent(
        timestamp: DateTime.utc(2025),
        message: 'crash',
        stackTrace: 'at line 42',
        errorType: 'TypeError',
        context: {'screen': 'home'},
      );

      final json = event.toJson();

      expect(json['stack_trace'], equals('at line 42'));
      expect(json['error_type'], equals('TypeError'));
      expect(json['context']['screen'], equals('home'));
    });
  });

  group('ScreenViewEvent', () {
    test('toJson with required fields', () {
      final event = ScreenViewEvent(
        timestamp: DateTime.utc(2025),
        screenName: 'HomeScreen',
      );

      final json = event.toJson();

      expect(json['screen_name'], equals('HomeScreen'));
      expect(json.containsKey('previous_screen'), isFalse);
      expect(json.containsKey('duration_ms'), isFalse);
    });

    test('toJson with all fields', () {
      final event = ScreenViewEvent(
        timestamp: DateTime.utc(2025),
        screenName: 'DetailScreen',
        previousScreen: 'HomeScreen',
        durationMs: 1500,
      );

      final json = event.toJson();

      expect(json['previous_screen'], equals('HomeScreen'));
      expect(json['duration_ms'], equals(1500));
    });
  });

  group('TraceEvent', () {
    test('toJson required fields', () {
      final event = TraceEvent(
        traceId: 'trace-123',
        spanId: 'span-456',
        name: 'GET /api/users',
        kind: 'client',
        startTime: DateTime.utc(2025, 1, 1, 12, 0, 0),
        endTime: DateTime.utc(2025, 1, 1, 12, 0, 1),
        durationMs: 1000,
        statusCode: 200,
        status: 'OK',
      );

      final json = event.toJson();

      expect(json['trace_id'], equals('trace-123'));
      expect(json['span_id'], equals('span-456'));
      expect(json['name'], equals('GET /api/users'));
      expect(json['kind'], equals('client'));
      expect(json['duration_ms'], equals(1000));
      expect(json['status_code'], equals(200));
      expect(json['status'], equals('OK'));
      expect(json.containsKey('parent_span_id'), isFalse);
      expect(json.containsKey('attributes'), isFalse);
    });

    test('toJson with parent and attributes', () {
      final event = TraceEvent(
        traceId: 'trace-123',
        spanId: 'span-456',
        parentSpanId: 'span-000',
        name: 'POST /api/orders',
        kind: 'server',
        startTime: DateTime.utc(2025),
        endTime: DateTime.utc(2025),
        durationMs: 200,
        statusCode: 201,
        status: 'OK',
        attributes: {'db.statement': 'INSERT INTO orders'},
      );

      final json = event.toJson();

      expect(json['parent_span_id'], equals('span-000'));
      expect(json['attributes']['db.statement'], equals('INSERT INTO orders'));
    });
  });

  group('PerformanceEvent', () {
    test('toJson required fields', () {
      final event = PerformanceEvent(
        timestamp: DateTime.utc(2025),
        metricName: 'frame_render_time',
        value: 16.7,
      );

      final json = event.toJson();

      expect(json['metric_name'], equals('frame_render_time'));
      expect(json['value'], equals(16.7));
      expect(json.containsKey('unit'), isFalse);
    });

    test('toJson with all fields', () {
      final event = PerformanceEvent(
        timestamp: DateTime.utc(2025),
        metricName: 'memory_usage',
        value: 150.0,
        unit: 'MB',
        tags: {'screen': 'dashboard'},
      );

      final json = event.toJson();

      expect(json['unit'], equals('MB'));
      expect(json['tags']['screen'], equals('dashboard'));
    });
  });
}
