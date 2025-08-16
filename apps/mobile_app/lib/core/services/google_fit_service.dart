import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

typedef ActivityDetectionCallback = void Function(String activityType, bool isActive);

class GoogleFitService {
  final Health _health = Health();
  Timer? _activityMonitorTimer;
  ActivityDetectionCallback? onActivityDetected;
  
  // Singleton pattern
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  final List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.HEART_RATE,
    HealthDataType.MOVE_MINUTES,
  ];

  static Future<bool> requestPermission({bool preferSamsung = false}) async {
    // Mandatory permissions
    List<Permission> permissions = [
      Permission.activityRecognition,
      Permission.sensors,
      Permission.locationWhenInUse,
    ];
    if (Platform.isAndroid && (await _isAndroid13OrUp())) {
      permissions.add(Permission.notification);
    }

    final statuses = await permissions.request();
    if (statuses.values.any((status) => !status.isGranted)) {
      return false;
    }

    // Request authorization from Google Fit or Samsung Health
    return await GoogleFitService().requestPermissions(preferSamsung: preferSamsung);
  }

  Future<bool> requestPermissions({bool preferSamsung = false}) async {
    final bool requested = await _health.requestAuthorization(
      _types,
      permissions: _types.map((e) => HealthDataAccess.READ).toList(),
    );
    return requested;
  }

  static Future<bool> _isAndroid13OrUp() async {
    if (!Platform.isAndroid) return false;
    // Android 13 = SDK 33, but package_info_plus or device_info_plus can be used here.
    // For simplification of the example, always request notification if Android.
    return true;
  }

  Future<bool> checkAllPermissionsGranted() async {
    try {
      final now = DateTime.now();
      await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: now.subtract(const Duration(minutes: 1)),
        endTime: now,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the current detailed exercise, if there is one in progress
  Future<Map<String, dynamic>?> getCurrentExerciseDetailed() async {
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 6));
    final workouts = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: now,
    );
    final ongoing = workouts.cast<HealthDataPoint?>().firstWhere(
      (point) => point != null && (point.dateTo == null || point.dateTo!.isAfter(now)),
      orElse: () => null,
    );
    if (ongoing == null) return null;
    return {
      'exerciseType': ongoing.typeString,
      'value': ongoing.value,
      'unit': ongoing.unitString,
      'startTime': ongoing.dateFrom.toIso8601String(),
      'endTime': ongoing.dateTo?.toIso8601String(),
      'source': ongoing.sourceName,
      'metadata': ongoing.metadata.toString(),
    };
  }

  /// Checks if there is any active exercise currently (e.g., walking, running, etc.)
  Future<String?> getCurrentActiveExerciseType() async {
    try {
      // First check for specific workout
      final exercise = await getCurrentExerciseDetailed();
      if (exercise != null) {
        return exercise['exerciseType'];
      }
      
      // If no specific workout, check for walking activity
      if (await isWalking()) {
        return "Walking";
      }
      
      return null;
    } catch (e) {
      debugPrint('Error detecting activity: $e');
      return null;
    }
  }
  
  /// Specifically checks if the user is walking
  Future<bool> isWalking() async {
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      
      // Check recent steps
      final steps = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: fiveMinutesAgo,
        endTime: now,
      );
      
      // Check if there are any steps in the last 5 minutes
      if (steps.isNotEmpty) {
        int totalSteps = 0;
        for (var step in steps) {
          if (step.value is NumericHealthValue) {
            totalSteps += (step.value as NumericHealthValue).numericValue.toInt();
          }
        }
        
        // If more than 20 steps in the last 5 minutes, consider it walking
        return totalSteps > 20;
      }
      
      // Also check move minutes as a fallback
      final moveMinutes = await _health.getHealthDataFromTypes(
        types: [HealthDataType.MOVE_MINUTES],
        startTime: fiveMinutesAgo,
        endTime: now,
      );
      
      // If there are any move minutes in the last 5 minutes, consider it walking
      return moveMinutes.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if walking: $e');
      return false;
    }
  }
  
  /// Starts continuous monitoring of user activity
  void startActivityMonitoring({ActivityDetectionCallback? callback}) {
    if (callback != null) {
      onActivityDetected = callback;
    }
    
    _activityMonitorTimer?.cancel();
    _activityMonitorTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      final activityType = await getCurrentActiveExerciseType();
      if (activityType != null && onActivityDetected != null) {
        onActivityDetected!(activityType, true);
      }
    });
  }
  
  /// Stops continuous monitoring of user activity
  void stopActivityMonitoring() {
    _activityMonitorTimer?.cancel();
    _activityMonitorTimer = null;
  }
}
