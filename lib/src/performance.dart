import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'omnipulse.dart';
import 'types.dart';

/// Performance tracker for Flutter applications
/// Monitors frame timing, jank detection, and app lifecycle
class OmniPulsePerformance {
  static OmniPulsePerformance? _instance;
  
  final OmniPulse _omnipulse;
  
  // Frame timing tracking
  List<int> _frameTimings = [];
  DateTime? _lastFrameTime;
  Timer? _metricsTimer;
  
  // Jank thresholds
  static const int jankThresholdMs = 16; // >16ms = missed 60fps frame
  static const int severeJankThresholdMs = 100; // >100ms = severe jank
  
  // Stats
  int _jankFrameCount = 0;
  int _severeJankCount = 0;
  int _totalFrames = 0;
  
  OmniPulsePerformance._(this._omnipulse);

  /// Initialize performance monitoring
  static OmniPulsePerformance init(OmniPulse omnipulse) {
    if (_instance != null) {
      return _instance!;
    }
    
    _instance = OmniPulsePerformance._(omnipulse);
    _instance!._startMonitoring();
    return _instance!;
  }

  /// Get the singleton instance
  static OmniPulsePerformance? get instance => _instance;

  void _startMonitoring() {
    // Start frame callback monitoring
    SchedulerBinding.instance.addPersistentFrameCallback(_onFrame);
    
    // Start periodic metrics reporting
    _metricsTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _reportMetrics(),
    );
    
    // Monitor app lifecycle
    WidgetsBinding.instance.addObserver(_LifecycleObserver(this));
  }

  void _onFrame(Duration timestamp) {
    final now = DateTime.now();
    
    if (_lastFrameTime != null) {
      final frameDuration = now.difference(_lastFrameTime!).inMilliseconds;
      _frameTimings.add(frameDuration);
      _totalFrames++;
      
      if (frameDuration > jankThresholdMs) {
        _jankFrameCount++;
        
        if (frameDuration > severeJankThresholdMs) {
          _severeJankCount++;
          // Report severe jank immediately
          _reportJank(frameDuration);
        }
      }
      
      // Keep only last 100 frame timings
      if (_frameTimings.length > 100) {
        _frameTimings.removeAt(0);
      }
    }
    
    _lastFrameTime = now;
  }

  void _reportJank(int frameDurationMs) {
    final event = PerformanceEvent(
      timestamp: DateTime.now(),
      metricName: 'flutter.jank',
      value: frameDurationMs.toDouble(),
      unit: 'ms',
      tags: {
        'severity': 'severe',
        'threshold_exceeded_by': frameDurationMs - severeJankThresholdMs,
      },
    );
    
    _omnipulse.addPerformance(event);
  }

  void _reportMetrics() {
    if (_frameTimings.isEmpty) return;
    
    final now = DateTime.now();
    
    // Calculate FPS
    final avgFrameTime = _frameTimings.reduce((a, b) => a + b) / _frameTimings.length;
    final fps = avgFrameTime > 0 ? (1000 / avgFrameTime) : 60;
    
    // Calculate P95 frame time
    final sorted = List<int>.from(_frameTimings)..sort();
    final p95Index = (sorted.length * 0.95).floor();
    final p95FrameTime = sorted[p95Index];
    
    // Report FPS
    _omnipulse.addPerformance(PerformanceEvent(
      timestamp: now,
      metricName: 'flutter.fps',
      value: fps,
      unit: 'fps',
    ));
    
    // Report P95 frame time
    _omnipulse.addPerformance(PerformanceEvent(
      timestamp: now,
      metricName: 'flutter.frame_time_p95',
      value: p95FrameTime.toDouble(),
      unit: 'ms',
    ));
    
    // Report jank rate
    final jankRate = _totalFrames > 0 
        ? (_jankFrameCount / _totalFrames) * 100 
        : 0;
    _omnipulse.addPerformance(PerformanceEvent(
      timestamp: now,
      metricName: 'flutter.jank_rate',
      value: jankRate,
      unit: 'percent',
      tags: {
        'jank_frames': _jankFrameCount,
        'severe_jank_frames': _severeJankCount,
        'total_frames': _totalFrames,
      },
    ));
    
    // Reset counters
    _jankFrameCount = 0;
    _severeJankCount = 0;
    _totalFrames = 0;
    _frameTimings.clear();
  }

  /// Manually report a custom performance metric
  void recordMetric(String name, double value, {String? unit, Map<String, dynamic>? tags}) {
    _omnipulse.addPerformance(PerformanceEvent(
      timestamp: DateTime.now(),
      metricName: name,
      value: value,
      unit: unit,
      tags: tags,
    ));
  }

  /// Time an async operation
  Future<T> timeAsync<T>(String operationName, Future<T> Function() operation) async {
    final stopwatch = Stopwatch()..start();
    try {
      return await operation();
    } finally {
      stopwatch.stop();
      recordMetric(
        'flutter.operation.$operationName',
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
      );
    }
  }

  /// Time a sync operation
  T timeSync<T>(String operationName, T Function() operation) {
    final stopwatch = Stopwatch()..start();
    try {
      return operation();
    } finally {
      stopwatch.stop();
      recordMetric(
        'flutter.operation.$operationName',
        stopwatch.elapsedMilliseconds.toDouble(),
        unit: 'ms',
      );
    }
  }

  /// Report app start time
  void reportAppStartTime(Duration startDuration) {
    recordMetric(
      'flutter.app_start_time',
      startDuration.inMilliseconds.toDouble(),
      unit: 'ms',
    );
  }

  /// Stop monitoring
  void dispose() {
    _metricsTimer?.cancel();
    _instance = null;
  }
}

/// Lifecycle observer for tracking app state changes
class _LifecycleObserver extends WidgetsBindingObserver {
  final OmniPulsePerformance _performance;
  DateTime? _pausedTime;
  
  _LifecycleObserver(this._performance);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final now = DateTime.now();
    
    switch (state) {
      case AppLifecycleState.paused:
        _pausedTime = now;
        _performance.recordMetric(
          'flutter.lifecycle',
          1,
          tags: {'state': 'paused'},
        );
        break;
      case AppLifecycleState.resumed:
        if (_pausedTime != null) {
          final pauseDuration = now.difference(_pausedTime!);
          _performance.recordMetric(
            'flutter.background_duration',
            pauseDuration.inMilliseconds.toDouble(),
            unit: 'ms',
          );
        }
        _performance.recordMetric(
          'flutter.lifecycle',
          1,
          tags: {'state': 'resumed'},
        );
        break;
      case AppLifecycleState.inactive:
        _performance.recordMetric(
          'flutter.lifecycle',
          1,
          tags: {'state': 'inactive'},
        );
        break;
      case AppLifecycleState.detached:
        _performance.recordMetric(
          'flutter.lifecycle',
          1,
          tags: {'state': 'detached'},
        );
        break;
      case AppLifecycleState.hidden:
        _performance.recordMetric(
          'flutter.lifecycle',
          1,
          tags: {'state': 'hidden'},
        );
        break;
    }
  }
}
