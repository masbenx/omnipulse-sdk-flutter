import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'types.dart';
import 'logger.dart';
import 'error_handler.dart';

/// Main OmniPulse client for Flutter applications
class OmniPulse {
  static OmniPulse? _instance;
  
  final OmniPulseConfig config;
  final http.Client _httpClient;
  final Uuid _uuid = const Uuid();
  
  late final OmniPulseLogger logger;
  late final OmniPulseErrorHandler errorHandler;
  
  final List<LogEntry> _logBuffer = [];
  final List<ErrorEvent> _errorBuffer = [];
  final List<ScreenViewEvent> _screenBuffer = [];
  final List<TraceEvent> _traceBuffer = [];
  final List<PerformanceEvent> _perfBuffer = [];
  
  Timer? _flushTimer;
  bool _isInitialized = false;

  OmniPulse._internal(this.config, this._httpClient) {
    logger = OmniPulseLogger(this);
    errorHandler = OmniPulseErrorHandler(this);
  }

  /// Initialize the OmniPulse SDK
  static Future<OmniPulse> init(OmniPulseConfig config) async {
    if (_instance != null) {
      return _instance!;
    }
    
    _instance = OmniPulse._internal(config, http.Client());
    await _instance!._initialize();
    return _instance!;
  }

  /// Get the singleton instance (must call init first)
  static OmniPulse get instance {
    if (_instance == null) {
      throw StateError('OmniPulse must be initialized first. Call OmniPulse.init()');
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;
    
    // Start flush timer
    _flushTimer = Timer.periodic(
      Duration(seconds: config.flushIntervalSeconds),
      (_) => flush(),
    );
    
    _isInitialized = true;
    
    if (config.debug) {
      debugPrint('[OmniPulse] Initialized with API: ${config.apiUrl}');
    }
  }

  /// Generate a unique ID
  String generateId() => _uuid.v4();

  /// Add a log entry to the buffer
  void addLog(LogEntry entry) {
    _logBuffer.add(entry);
    _checkFlush();
  }

  /// Add an error event to the buffer
  void addError(ErrorEvent event) {
    _errorBuffer.add(event);
    _checkFlush();
  }

  /// Add a screen view event to the buffer
  void addScreenView(ScreenViewEvent event) {
    _screenBuffer.add(event);
    _checkFlush();
  }

  /// Add a trace event to the buffer
  void addTrace(TraceEvent event) {
    _traceBuffer.add(event);
    _checkFlush();
  }

  /// Add a performance event to the buffer
  void addPerformance(PerformanceEvent event) {
    _perfBuffer.add(event);
    _checkFlush();
  }

  void _checkFlush() {
    final totalItems = _logBuffer.length + _errorBuffer.length + 
        _screenBuffer.length + _traceBuffer.length + _perfBuffer.length;
    if (totalItems >= config.batchSize) {
      flush();
    }
  }

  /// Flush all buffered data immediately
  Future<void> flush() async {
    final logs = List<LogEntry>.from(_logBuffer);
    final errors = List<ErrorEvent>.from(_errorBuffer);
    final screens = List<ScreenViewEvent>.from(_screenBuffer);
    final traces = List<TraceEvent>.from(_traceBuffer);
    final perfs = List<PerformanceEvent>.from(_perfBuffer);
    
    _logBuffer.clear();
    _errorBuffer.clear();
    _screenBuffer.clear();
    _traceBuffer.clear();
    _perfBuffer.clear();

    if (logs.isNotEmpty) {
      await _sendLogs(logs);
    }
    if (errors.isNotEmpty) {
      await _sendErrors(errors);
    }
    if (screens.isNotEmpty) {
      await _sendScreenViews(screens);
    }
    if (traces.isNotEmpty) {
      await _sendTraces(traces);
    }
    if (perfs.isNotEmpty) {
      await _sendPerformance(perfs);
    }
  }

  Future<void> _sendLogs(List<LogEntry> logs) async {
    try {
      final payload = {
        'logs': logs.map((l) => l.toJson()).toList(),
      };
      await _send('/api/ingest/app-logs', payload);
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Failed to send logs: $e');
      }
    }
  }

  Future<void> _sendErrors(List<ErrorEvent> errors) async {
    try {
      final payload = {
        'errors': errors.map((e) => e.toJson()).toList(),
      };
      await _send('/api/ingest/app-errors', payload);
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Failed to send errors: $e');
      }
    }
  }

  Future<void> _sendScreenViews(List<ScreenViewEvent> screens) async {
    try {
      final payload = {
        'screens': screens.map((s) => s.toJson()).toList(),
      };
      await _send('/api/ingest/app-screens', payload);
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Failed to send screen views: $e');
      }
    }
  }

  Future<void> _sendTraces(List<TraceEvent> traces) async {
    try {
      final payload = {
        'traces': traces.map((t) => t.toJson()).toList(),
      };
      await _send('/api/ingest/app-traces', payload);
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Failed to send traces: $e');
      }
    }
  }

  Future<void> _sendPerformance(List<PerformanceEvent> perfs) async {
    try {
      final payload = {
        'metrics': perfs.map((p) => p.toJson()).toList(),
      };
      await _send('/api/ingest/app-metrics', payload);
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Failed to send performance metrics: $e');
      }
    }
  }

  Future<void> _send(String endpoint, Map<String, dynamic> payload) async {
    final uri = Uri.parse('${config.apiUrl}$endpoint');
    final body = jsonEncode(payload);
    
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Ingest-Key': config.ingestKey,
        'User-Agent': 'omnipulse-flutter-sdk/1.0.0',
      },
      body: body,
    ).timeout(const Duration(seconds: 5));
    
    if (config.debug) {
      debugPrint('[OmniPulse] Sent to $endpoint, status: ${response.statusCode}');
    }
  }

  /// Test connectivity to the OmniPulse backend
  Future<bool> test() async {
    try {
      logger.info('OmniPulse SDK test message', {
        'sdk_version': '1.0.0',
        'platform': Platform.operatingSystem,
        'app_name': config.appName,
      });
      await flush();
      return true;
    } catch (e) {
      if (config.debug) {
        debugPrint('[OmniPulse] Test failed: $e');
      }
      return false;
    }
  }

  /// Close the SDK and flush remaining data
  Future<void> close() async {
    _flushTimer?.cancel();
    await flush();
    _httpClient.close();
    _instance = null;
  }
}
