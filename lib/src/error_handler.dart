import 'dart:async';

import 'package:flutter/foundation.dart';

import 'types.dart';
import 'omnipulse.dart';

/// Error handler for OmniPulse Flutter SDK
class OmniPulseErrorHandler {
  final OmniPulse _client;

  OmniPulseErrorHandler(this._client);

  /// Capture a Flutter error
  void captureFlutterError(FlutterErrorDetails details) {
    final event = ErrorEvent(
      timestamp: DateTime.now(),
      message: details.exceptionAsString(),
      stackTrace: details.stack?.toString(),
      errorType: details.exception.runtimeType.toString(),
      context: {
        'library': details.library ?? 'unknown',
        if (details.context != null) 'context': details.context.toString(),
      },
    );
    _client.addError(event);
  }

  /// Capture a generic exception
  void captureException(Object exception, [StackTrace? stackTrace, Map<String, dynamic>? context]) {
    final event = ErrorEvent(
      timestamp: DateTime.now(),
      message: exception.toString(),
      stackTrace: stackTrace?.toString(),
      errorType: exception.runtimeType.toString(),
      context: context,
    );
    _client.addError(event);
  }

  /// Wrap a function to automatically capture errors
  T? runGuarded<T>(T Function() fn, {Map<String, dynamic>? context}) {
    try {
      return fn();
    } catch (e, stackTrace) {
      captureException(e, stackTrace, context);
      return null;
    }
  }

  /// Wrap an async function to automatically capture errors
  Future<T?> runGuardedAsync<T>(Future<T> Function() fn, {Map<String, dynamic>? context}) async {
    try {
      return await fn();
    } catch (e, stackTrace) {
      captureException(e, stackTrace, context);
      return null;
    }
  }

  /// Setup global error handling
  void setupGlobalErrorHandling() {
    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      captureFlutterError(details);
      // Also print to console in debug mode
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
    };

    // Capture async errors using runZonedGuarded
    // This should be called in main() by wrapping runApp
  }
}

/// Run the app with OmniPulse error handling
void runAppWithOmniPulse(Widget Function() appBuilder) {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      OmniPulse.instance.errorHandler.setupGlobalErrorHandling();
      runApp(appBuilder());
    },
    (error, stackTrace) {
      OmniPulse.instance.errorHandler.captureException(error, stackTrace);
    },
  );
}

// Stub for runApp - actual import would come from flutter
void runApp(Object app) {
  // This is a stub - the real flutter framework provides this
}

// Stub for WidgetsFlutterBinding - actual import would come from flutter
class WidgetsFlutterBinding {
  static void ensureInitialized() {}
}

// Stub for Widget
abstract class Widget {}
