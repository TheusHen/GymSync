import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'background_location_service.dart';
import 'foreground_workout_service.dart';

/// Service to handle app lifecycle and background state management
class AppStateService {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  StreamSubscription<AppLifecycleState>? _subscription;
  
  /// Initialize app state monitoring
  void initialize() {
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(_AppLifecycleObserver());
  }

  /// Handle app going to background
  static Future<void> onAppPaused() async {
    debugPrint('App paused - ensuring background services are active');
    
    // Ensure background location monitoring is running
    try {
      await BackgroundLocationService().startLocationMonitoring();
    } catch (e) {
      debugPrint('Error starting background location monitoring: $e');
    }
    
    // Check if workout is active and ensure foreground service is running
    try {
      final prefs = await SharedPreferences.getInstance();
      final activity = prefs.getString('current_activity');
      if (activity != null && !ForegroundWorkoutService().isRunning) {
        await ForegroundWorkoutService().startWorkoutTracking(activity);
      }
    } catch (e) {
      debugPrint('Error checking workout state on pause: $e');
    }
  }

  /// Handle app coming to foreground
  static Future<void> onAppResumed() async {
    debugPrint('App resumed - syncing state');
    
    // Sync any state changes that might have happened in background
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastInGym = prefs.getBool('last_in_gym') ?? false;
      debugPrint('Last known gym state: $lastInGym');
    } catch (e) {
      debugPrint('Error syncing state on resume: $e');
    }
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        AppStateService.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        AppStateService.onAppResumed();
        break;
      case AppLifecycleState.detached:
        // App is being terminated
        debugPrint('App detached');
        break;
      case AppLifecycleState.inactive:
        // App is in transition state
        break;
      case AppLifecycleState.hidden:
        // App is hidden but still running
        break;
    }
  }
}