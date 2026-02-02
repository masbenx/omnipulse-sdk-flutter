import 'types.dart';
import 'omnipulse.dart';

/// Logger for OmniPulse Flutter SDK
class OmniPulseLogger {
  final OmniPulse _client;

  OmniPulseLogger(this._client);

  /// Log a debug message
  void debug(String message, [Map<String, dynamic>? tags]) {
    _log(LogLevel.debug, message, tags);
  }

  /// Log an info message
  void info(String message, [Map<String, dynamic>? tags]) {
    _log(LogLevel.info, message, tags);
  }

  /// Log a warning message
  void warn(String message, [Map<String, dynamic>? tags]) {
    _log(LogLevel.warn, message, tags);
  }

  /// Log an error message
  void error(String message, [Map<String, dynamic>? tags]) {
    _log(LogLevel.error, message, tags);
  }

  /// Log a fatal message
  void fatal(String message, [Map<String, dynamic>? tags]) {
    _log(LogLevel.fatal, message, tags);
  }

  void _log(LogLevel level, String message, Map<String, dynamic>? tags) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      serviceName: _client.config.appName,
      tags: tags,
    );
    _client.addLog(entry);
  }
}
