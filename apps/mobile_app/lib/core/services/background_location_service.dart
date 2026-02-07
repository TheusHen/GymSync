import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'backend_service.dart';

/// Background location monitoring service using WorkManager.
/// Runs independently of the main app and monitors gym proximity.
class BackgroundLocationService {
  static const String _locationTaskName = 'com.gymsync.location_monitor';
  static const double gymRadiusMeters = 35.0;

  static final BackgroundLocationService _instance = BackgroundLocationService._internal();
  factory BackgroundLocationService() => _instance;
  BackgroundLocationService._internal();

  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: kDebugMode,
    );
  }

  Future<void> startLocationMonitoring() async {
    try {
      await Workmanager().registerPeriodicTask(
        _locationTaskName,
        _locationTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.notRequired,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
        inputData: <String, dynamic>{
          'task': 'location_monitor',
        },
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      debugPrint('Background location monitoring started');
    } catch (e) {
      debugPrint('Failed to start background location monitoring: $e');
      rethrow;
    }
  }

  Future<void> stopLocationMonitoring() async {
    try {
      await Workmanager().cancelByUniqueName(_locationTaskName);
      debugPrint('Background location monitoring stopped');
    } catch (e) {
      debugPrint('Failed to stop background location monitoring: $e');
    }
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('WorkManager task: $task executed at ${DateTime.now()}');
    try {
      if (task == _BackgroundHandler._locationTaskName) {
        await _BackgroundHandler.handleLocationMonitoring();
      }
      return true;
    } catch (e) {
      debugPrint('WorkManager task failed: $e');
      return false;
    }
  });
}

class _BackgroundHandler {
  static const String _locationTaskName = 'com.gymsync.location_monitor';

  static Future<void> handleLocationMonitoring() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('gym_lat');
      final lng = prefs.getDouble('gym_lng');

      if (lat == null || lng == null) {
        debugPrint('No gym location set, skipping monitoring');
        return;
      }

      final gymLoc = LatLng(lat, lng);
      final wasInGym = prefs.getBool('last_in_gym') ?? false;

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) {
          debugPrint('Could not get location: $e');
          return;
        }
      }

      final Distance distance = Distance();
      final double dist = distance(
        LatLng(position.latitude, position.longitude),
        gymLoc,
      );

      final bool nowInGym = dist <= BackgroundLocationService.gymRadiusMeters;
      await prefs.setBool('last_in_gym', nowInGym);

      debugPrint('Background location: distance=$dist, inGym=$nowInGym, wasInGym=$wasInGym');

      if (!wasInGym && nowInGym) {
        await _handleGymArrival(prefs);
      } else if (wasInGym && !nowInGym) {
        await _handleGymDeparture();
      } else if (nowInGym) {
        // Send heartbeat to keep session alive
        await BackendService.heartbeat();
      }
    } catch (e) {
      debugPrint('Error in background location monitoring: $e');
    }
  }

  static Future<void> _handleGymArrival(SharedPreferences prefs) async {
    debugPrint('Gym arrival detected in background');
    try {
      await BackendService.start("Gym");
      await prefs.setString('current_activity', 'Gym');
      await prefs.setInt('workout_start_time', DateTime.now().millisecondsSinceEpoch);
      await _showNotification(
        'Welcome to the Gym!',
        'Your workout timer has started automatically.',
      );
    } catch (e) {
      debugPrint('Error handling gym arrival: $e');
    }
  }

  static Future<void> _handleGymDeparture() async {
    debugPrint('Gym departure detected in background');
    try {
      final data = await BackendService.getStatus();
      if (data != null) {
        final activity = data['activity'];
        final isPaused = data['paused'] == true;

        if (!isPaused && activity == "Gym") {
          await BackendService.pause();
          await _showNotification(
            'Workout Paused',
            'You left the gym. Your workout is paused.',
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling gym departure: $e');
    }
  }

  static Future<void> _showNotification(String title, String body) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const android = AndroidInitializationSettings('ic_notification');
      const ios = DarwinInitializationSettings();
      await plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      const androidDetails = AndroidNotificationDetails(
        'gym_background_channel',
        'Gym Background',
        channelDescription: 'Background gym location notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
      );
      await plugin.show(
        3,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('Error showing background notification: $e');
    }
  }
}
