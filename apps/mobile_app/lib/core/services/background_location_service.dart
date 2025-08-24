import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'backend_service.dart';

/// Background location monitoring service using WorkManager
/// This runs independently of the main app and monitors gym location
class BackgroundLocationService {
  static const String _locationTaskName = 'com.gymsync.location_monitor';
  static const double gymRadiusMeters = 35.0;
  
  // Singleton pattern
  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  /// Initialize the background location service
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  /// Start periodic location monitoring
  Future<void> startLocationMonitoring() async {
    await Workmanager().registerPeriodicTask(
      _locationTaskName,
      _locationTaskName,
      frequency: const Duration(minutes: 15), // Minimum allowed by WorkManager
      constraints: Constraints(
        networkType: NetworkType.not_required,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
      inputData: <String, dynamic>{
        'task': 'location_monitor'
      },
    );
    debugPrint('Background location monitoring started');
  }

  /// Stop location monitoring
  Future<void> stopLocationMonitoring() async {
    await Workmanager().cancelByUniqueName(_locationTaskName);
    debugPrint('Background location monitoring stopped');
  }
}

/// Callback dispatcher for WorkManager
/// This runs in a separate isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('WorkManager task: $task executed at ${DateTime.now()}');
    
    try {
      switch (task) {
        case 'com.gymsync.location_monitor':
          await _handleLocationMonitoring();
          break;
        default:
          debugPrint('Unknown task: $task');
      }
      return Future.value(true);
    } catch (e) {
      debugPrint('WorkManager task failed: $e');
      return Future.value(false);
    }
  });
}

/// Handle location monitoring in background
Future<void> _handleLocationMonitoring() async {
  try {
    // Load gym location from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('gym_lat');
    final lng = prefs.getDouble('gym_lng');
    
    if (lat == null || lng == null) {
      debugPrint('No gym location set, skipping monitoring');
      return;
    }
    
    final gymLoc = LatLng(lat, lng);
    final wasInGym = prefs.getBool('last_in_gym') ?? false;
    
    // Get current location
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 30),
      );
    } catch (e) {
      // Fallback to last known position
      position = await Geolocator.getLastKnownPosition();
      if (position == null) {
        debugPrint('Could not get location: $e');
        return;
      }
    }
    
    // Calculate distance to gym
    final Distance distance = Distance();
    final double dist = distance(
      LatLng(position.latitude, position.longitude),
      gymLoc,
    );
    
    final bool nowInGym = dist <= BackgroundLocationService.gymRadiusMeters;
    await prefs.setBool('last_in_gym', nowInGym);
    
    debugPrint('Background location check: distance=$dist, inGym=$nowInGym, wasInGym=$wasInGym');
    
    // Handle gym arrival
    if (!wasInGym && nowInGym) {
      await _handleGymArrival();
    }
    
    // Handle gym departure
    if (wasInGym && !nowInGym) {
      await _handleGymDeparture();
    }
    
    // If currently in gym, ensure workout is tracking
    if (nowInGym) {
      await _ensureGymTracking();
    }
    
  } catch (e) {
    debugPrint('Error in background location monitoring: $e');
  }
}

/// Handle gym arrival
Future<void> _handleGymArrival() async {
  debugPrint('Gym arrival detected in background');
  
  try {
    // Start gym workout
    await BackendService.start("Gym");
    
    // Show notification
    await _showBackgroundNotification(
      'Welcome to the Gym!',
      'Your workout timer has started automatically.'
    );
  } catch (e) {
    debugPrint('Error handling gym arrival: $e');
  }
}

/// Handle gym departure
Future<void> _handleGymDeparture() async {
  debugPrint('Gym departure detected in background');
  
  try {
    // Get current status to see if we were tracking a gym workout
    final data = await BackendService.getStatus();
    final activity = data?['status']?['activity'];
    final isActive = (data?['status']?['state'] ?? 'paused') == 'active';
    
    if (isActive && activity == "Gym") {
      // Stop gym workout
      await BackendService.stop();
      
      // Show notification
      await _showBackgroundNotification(
        'Gym Workout Ended',
        'Your gym session has been automatically stopped.'
      );
    }
  } catch (e) {
    debugPrint('Error handling gym departure: $e');
  }
}

/// Ensure gym tracking is active when in gym
Future<void> _ensureGymTracking() async {
  try {
    // Check if we're already tracking gym
    final data = await BackendService.getStatus();
    final activity = data?['status']?['activity'];
    final isActive = (data?['status']?['state'] ?? 'paused') == 'active';
    
    if (!isActive || activity != "Gym") {
      // Start gym tracking if not already active
      await BackendService.start("Gym");
      debugPrint('Started gym tracking from background');
    }
  } catch (e) {
    debugPrint('Error ensuring gym tracking: $e');
  }
}

/// Show background notification
Future<void> _showBackgroundNotification(String title, String body) async {
  try {
    // This is a simplified notification for background context
    // The actual notification implementation may vary based on platform
    debugPrint('Background notification: $title - $body');
  } catch (e) {
    debugPrint('Error showing background notification: $e');
  }
}