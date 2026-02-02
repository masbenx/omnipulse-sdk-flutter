import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'omnipulse.dart';
import 'types.dart';

/// HTTP Client wrapper that automatically traces all HTTP requests
/// 
/// Usage:
/// ```dart
/// final client = OmniPulseHttpClient();
/// final response = await client.get(Uri.parse('https://api.example.com/data'));
/// ```
class OmniPulseHttpClient extends http.BaseClient {
  final http.Client _inner;
  final bool logRequestBody;
  final bool logResponseBody;
  final int maxBodyLogSize;
  final List<String> sensitiveHeaders;

  OmniPulseHttpClient({
    http.Client? client,
    this.logRequestBody = false,
    this.logResponseBody = false,
    this.maxBodyLogSize = 10000,
    this.sensitiveHeaders = const [
      'authorization',
      'x-api-key',
      'x-ingest-key',
      'cookie',
      'set-cookie',
    ],
  }) : _inner = client ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final startTime = DateTime.now();
    final traceId = OmniPulse.instance.generateId();
    final spanId = OmniPulse.instance.generateId().substring(0, 16);
    
    // Add trace headers for distributed tracing
    request.headers['X-OmniPulse-Trace-ID'] = traceId;
    request.headers['X-OmniPulse-Span-ID'] = spanId;

    http.StreamedResponse? response;
    Object? error;
    StackTrace? stackTrace;

    try {
      response = await _inner.send(request);
      return response;
    } catch (e, st) {
      error = e;
      stackTrace = st;
      rethrow;
    } finally {
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;
      
      _recordTrace(
        request: request,
        response: response,
        error: error,
        stackTrace: stackTrace,
        traceId: traceId,
        spanId: spanId,
        startTime: startTime,
        endTime: endTime,
        durationMs: durationMs,
      );
    }
  }

  void _recordTrace({
    required http.BaseRequest request,
    http.StreamedResponse? response,
    Object? error,
    StackTrace? stackTrace,
    required String traceId,
    required String spanId,
    required DateTime startTime,
    required DateTime endTime,
    required int durationMs,
  }) {
    try {
      final attributes = <String, dynamic>{
        'http.method': request.method,
        'http.url': request.url.toString(),
        'http.host': request.url.host,
        'http.path': request.url.path,
        'http.scheme': request.url.scheme,
        'span.kind': 'client',
      };

      // Add request headers (redacted)
      final requestHeaders = <String, String>{};
      request.headers.forEach((key, value) {
        if (sensitiveHeaders.contains(key.toLowerCase())) {
          requestHeaders[key] = '[REDACTED]';
        } else {
          requestHeaders[key] = value;
        }
      });
      attributes['http.request_headers'] = requestHeaders;

      // Add response info if available
      if (response != null) {
        attributes['http.status_code'] = response.statusCode;
        attributes['http.response_content_length'] = response.contentLength;
        
        // Add response headers (redacted)
        final responseHeaders = <String, String>{};
        response.headers.forEach((key, value) {
          if (sensitiveHeaders.contains(key.toLowerCase())) {
            responseHeaders[key] = '[REDACTED]';
          } else {
            responseHeaders[key] = value;
          }
        });
        attributes['http.response_headers'] = responseHeaders;
      }

      // Add error info
      if (error != null) {
        attributes['error'] = true;
        attributes['error.type'] = error.runtimeType.toString();
        attributes['error.message'] = error.toString();
        if (stackTrace != null) {
          attributes['error.stack'] = stackTrace.toString().substring(
            0, 
            stackTrace.toString().length > 2000 ? 2000 : stackTrace.toString().length,
          );
        }
      }

      // Create trace event
      final trace = TraceEvent(
        traceId: traceId,
        spanId: spanId,
        name: '${request.method} ${request.url.path}',
        kind: 'client',
        startTime: startTime,
        endTime: endTime,
        durationMs: durationMs,
        statusCode: response?.statusCode ?? 0,
        status: _getStatus(response?.statusCode, error),
        attributes: attributes,
      );

      OmniPulse.instance.addTrace(trace);
    } catch (e) {
      if (OmniPulse.instance.config.debug) {
        debugPrint('[OmniPulse] Failed to record HTTP trace: $e');
      }
    }
  }

  String _getStatus(int? statusCode, Object? error) {
    if (error != null) return 'error';
    if (statusCode == null) return 'error';
    if (statusCode >= 200 && statusCode < 400) return 'ok';
    if (statusCode >= 400) return 'error';
    return 'ok';
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Extension to add convenience methods
extension OmniPulseHttpExtension on http.Client {
  /// Wrap this client with OmniPulse tracing
  OmniPulseHttpClient withTracing({
    bool logRequestBody = false,
    bool logResponseBody = false,
    int maxBodyLogSize = 10000,
  }) {
    return OmniPulseHttpClient(
      client: this,
      logRequestBody: logRequestBody,
      logResponseBody: logResponseBody,
      maxBodyLogSize: maxBodyLogSize,
    );
  }
}
