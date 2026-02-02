/// Log level enumeration
enum LogLevel { debug, info, warn, error, fatal }

/// Configuration for the OmniPulse SDK
class OmniPulseConfig {
  /// The OmniPulse API URL
  final String apiUrl;
  
  /// Your X-Ingest-Key for authentication
  final String ingestKey;
  
  /// Name of your application
  final String appName;
  
  /// Application version
  final String? appVersion;
  
  /// Environment (production, staging, development)
  final String environment;
  
  /// Enable debug logging
  final bool debug;
  
  /// Batch size before sending
  final int batchSize;
  
  /// Flush interval in seconds
  final int flushIntervalSeconds;

  const OmniPulseConfig({
    required this.apiUrl,
    required this.ingestKey,
    required this.appName,
    this.appVersion,
    this.environment = 'production',
    this.debug = false,
    this.batchSize = 50,
    this.flushIntervalSeconds = 10,
  });
}

/// Log entry data
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? serviceName;
  final Map<String, dynamic>? tags;
  final String? traceId;
  final String? spanId;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.serviceName,
    this.tags,
    this.traceId,
    this.spanId,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name,
    'message': message,
    if (serviceName != null) 'service_name': serviceName,
    if (tags != null) 'tags': tags,
    if (traceId != null) 'trace_id': traceId,
    if (spanId != null) 'span_id': spanId,
  };
}

/// Error event data
class ErrorEvent {
  final DateTime timestamp;
  final String message;
  final String? stackTrace;
  final String? errorType;
  final Map<String, dynamic>? context;

  ErrorEvent({
    required this.timestamp,
    required this.message,
    this.stackTrace,
    this.errorType,
    this.context,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'message': message,
    if (stackTrace != null) 'stack_trace': stackTrace,
    if (errorType != null) 'error_type': errorType,
    if (context != null) 'context': context,
  };
}

/// Screen view event
class ScreenViewEvent {
  final DateTime timestamp;
  final String screenName;
  final String? previousScreen;
  final int? durationMs;

  ScreenViewEvent({
    required this.timestamp,
    required this.screenName,
    this.previousScreen,
    this.durationMs,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'screen_name': screenName,
    if (previousScreen != null) 'previous_screen': previousScreen,
    if (durationMs != null) 'duration_ms': durationMs,
  };
}

/// Trace event for distributed tracing
class TraceEvent {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final String name;
  final String kind;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMs;
  final int statusCode;
  final String status;
  final Map<String, dynamic>? attributes;

  TraceEvent({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.name,
    required this.kind,
    required this.startTime,
    required this.endTime,
    required this.durationMs,
    required this.statusCode,
    required this.status,
    this.attributes,
  });

  Map<String, dynamic> toJson() => {
    'trace_id': traceId,
    'span_id': spanId,
    if (parentSpanId != null) 'parent_span_id': parentSpanId,
    'name': name,
    'kind': kind,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'duration_ms': durationMs,
    'status_code': statusCode,
    'status': status,
    if (attributes != null) 'attributes': attributes,
  };
}

/// Performance metric event
class PerformanceEvent {
  final DateTime timestamp;
  final String metricName;
  final double value;
  final String? unit;
  final Map<String, dynamic>? tags;

  PerformanceEvent({
    required this.timestamp,
    required this.metricName,
    required this.value,
    this.unit,
    this.tags,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'metric_name': metricName,
    'value': value,
    if (unit != null) 'unit': unit,
    if (tags != null) 'tags': tags,
  };
}
