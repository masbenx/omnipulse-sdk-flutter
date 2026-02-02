import 'package:flutter/material.dart';

import 'types.dart';
import 'omnipulse.dart';

/// Navigator observer for automatic screen tracking
class OmniPulseNavigatorObserver extends NavigatorObserver {
  String? _currentRoute;
  DateTime? _currentRouteStartTime;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _trackScreenChange(route.settings.name, previousRoute?.settings.name);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _trackScreenChange(previousRoute.settings.name, route.settings.name);
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _trackScreenChange(newRoute?.settings.name, oldRoute?.settings.name);
  }

  void _trackScreenChange(String? newScreen, String? previousScreen) {
    if (newScreen == null) return;

    // Calculate duration on previous screen
    int? durationMs;
    if (_currentRouteStartTime != null) {
      durationMs = DateTime.now().difference(_currentRouteStartTime!).inMilliseconds;
    }

    final event = ScreenViewEvent(
      timestamp: DateTime.now(),
      screenName: newScreen,
      previousScreen: _currentRoute,
      durationMs: durationMs,
    );

    try {
      OmniPulse.instance.addScreenView(event);
    } catch (e) {
      // SDK not initialized yet, ignore
    }

    _currentRoute = newScreen;
    _currentRouteStartTime = DateTime.now();
  }

  /// Manually track a screen view
  static void trackScreen(String screenName, {Map<String, dynamic>? properties}) {
    final event = ScreenViewEvent(
      timestamp: DateTime.now(),
      screenName: screenName,
    );
    try {
      OmniPulse.instance.addScreenView(event);
    } catch (e) {
      // SDK not initialized yet, ignore
    }
  }
}
