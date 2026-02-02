# OmniPulse Flutter SDK

The official OmniPulse SDK for Flutter applications. Provides logging, error tracking, and screen tracking with automatic navigation observation.

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  omnipulse_flutter: ^1.0.0
```

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:omnipulse_flutter/omnipulse_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize OmniPulse
  await OmniPulse.init(OmniPulseConfig(
    apiUrl: 'https://api.omnipulse.cloud',
    ingestKey: 'your-ingest-key',
    appName: 'My Flutter App',
    appVersion: '1.0.0',
    environment: 'production',
  ));

  // Test connectivity
  await OmniPulse.instance.test();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Add navigator observer for automatic screen tracking
      navigatorObservers: [OmniPulseNavigatorObserver()],
      home: HomeScreen(),
    );
  }
}
```

## Features

### Logging

```dart
final logger = OmniPulse.instance.logger;

logger.debug('Debug message');
logger.info('User logged in', {'user_id': 123});
logger.warn('Low memory warning');
logger.error('Failed to fetch data', {'error': e.toString()});
logger.fatal('Critical error occurred');
```

### Error Tracking

```dart
// Capture exceptions manually
try {
  await someOperation();
} catch (e, stackTrace) {
  OmniPulse.instance.errorHandler.captureException(e, stackTrace, {
    'operation': 'someOperation',
    'user_id': userId,
  });
}

// Use guarded execution
final result = OmniPulse.instance.errorHandler.runGuarded(() {
  return riskyOperation();
});

// Async guarded execution
final data = await OmniPulse.instance.errorHandler.runGuardedAsync(() async {
  return await fetchData();
});
```

### Global Error Handling

Wrap your app to catch all unhandled errors:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await OmniPulse.init(config);
  
  runZonedGuarded(
    () {
      OmniPulse.instance.errorHandler.setupGlobalErrorHandling();
      runApp(MyApp());
    },
    (error, stackTrace) {
      OmniPulse.instance.errorHandler.captureException(error, stackTrace);
    },
  );
}
```

### Screen Tracking

Automatic with NavigatorObserver:

```dart
MaterialApp(
  navigatorObservers: [OmniPulseNavigatorObserver()],
  // ...
)
```

Manual tracking:

```dart
OmniPulseNavigatorObserver.trackScreen('ProductDetailScreen', properties: {
  'product_id': productId,
});
```

### HTTP Client Wrapper

Automatically trace all HTTP requests:

```dart
import 'package:omnipulse_flutter/omnipulse_flutter.dart';

// Use OmniPulseHttpClient instead of http.Client
final client = OmniPulseHttpClient();

// All requests are automatically traced
final response = await client.get(Uri.parse('https://api.example.com/data'));

// Or wrap an existing client
final existingClient = http.Client().withTracing();
```

Features:
- Automatic request/response tracing
- Distributed trace propagation (X-OmniPulse-Trace-ID header)
- Sensitive header redaction (Authorization, Cookie, etc.)
- Error tracking with stack traces

### Performance Tracking (Jank Detection)

Monitor app performance and detect jank:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await OmniPulse.init(config);
  
  // Start performance monitoring
  OmniPulsePerformance.init(OmniPulse.instance);
  
  runApp(MyApp());
}

// Access performance tracker
final perf = OmniPulsePerformance.instance!;

// Time async operations
final data = await perf.timeAsync('fetchUserData', () async {
  return await api.getUserData();
});

// Time sync operations
final result = perf.timeSync('parseJson', () {
  return json.decode(responseBody);
});

// Report app start time
perf.reportAppStartTime(Duration(milliseconds: 850));

// Record custom metrics
perf.recordMetric('image_load_time', 234.5, unit: 'ms', tags: {
  'image_url': imageUrl,
});
```

Automatic metrics collected:
- **FPS** - Frames per second
- **Frame time P95** - 95th percentile frame render time
- **Jank rate** - Percentage of janky frames (>16ms)
- **Severe jank** - Frames taking >100ms
- **App lifecycle** - Background/foreground transitions
- **Background duration** - Time spent in background

## Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `apiUrl` | OmniPulse API URL | Required |
| `ingestKey` | Your ingest key | Required |
| `appName` | Your app name | Required |
| `appVersion` | App version | null |
| `environment` | Deployment environment | `production` |
| `debug` | Enable debug logging | `false` |
| `batchSize` | Buffer size before sending | `50` |
| `flushIntervalSeconds` | Flush interval | `10` |

## Best Practices

1. **Initialize early** - Call `OmniPulse.init()` before `runApp()`
2. **Use NavigatorObserver** - For automatic screen tracking
3. **Use OmniPulseHttpClient** - For automatic HTTP tracing
4. **Enable performance monitoring** - Call `OmniPulsePerformance.init()`
5. **Setup error handling** - Use `runZonedGuarded` for global error capture
6. **Close on dispose** - Call `OmniPulse.instance.close()` if needed
7. **Add context** - Include relevant context in logs and errors

## License

MIT
