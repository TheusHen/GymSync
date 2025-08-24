import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:samsung_health_handler/samsung_health_handler.dart';
import 'package:permission_handler/permission_handler.dart';

typedef ActivityDetectionCallback = void Function(String activityType, bool isActive);

class SamsungHealthService {
  Timer? _activityMonitorTimer;
  ActivityDetectionCallback? onActivityDetected;
  
  // Singleton pattern
  static final SamsungHealthService _instance = SamsungHealthService._internal();
  factory SamsungHealthService() => _instance;
  SamsungHealthService._internal();

  static Future<bool> requestPermission() async {
    try {
      // Request Samsung Health permissions
      final result = await SamsungHealthHandler.requestPermissions([
        HealthDataType.STEP_COUNT,
        HealthDataType.EXERCISE,
        HealthDataType.HEART_RATE,
        HealthDataType.DISTANCE,
      ]);
      
      return result;
    } catch (e) {
      debugPrint('Error requesting Samsung Health permissions: $e');
      return false;
    }
  }

  Future<bool> checkAllPermissionsGranted() async {
    try {
      // Try to read recent step data to verify permissions
      final now = DateTime.now();
      final startTime = now.subtract(const Duration(minutes: 1));
      
      await SamsungHealthHandler.readStepCount(startTime, now);
      return true;
    } catch (e) {
      debugPrint('Samsung Health permissions not granted: $e');
      return false;
    }
  }

  /// Returns the current detailed exercise, if there is one in progress
  Future<Map<String, dynamic>?> getCurrentExerciseDetailed() async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(hours: 6));
      
      final exercises = await SamsungHealthHandler.readExercises(start, now);
      
      // Find ongoing exercise (no end time or end time is in the future)
      for (var exercise in exercises) {
        if (exercise.endTime == null || exercise.endTime!.isAfter(now)) {
          return {
            'exerciseType': _mapExerciseType(exercise.exerciseType),
            'value': exercise.duration?.inSeconds ?? 0,
            'unit': 'seconds',
            'startTime': exercise.startTime.toIso8601String(),
            'endTime': exercise.endTime?.toIso8601String(),
            'source': 'Samsung Health',
            'metadata': exercise.toString(),
          };
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting current exercise from Samsung Health: $e');
      return null;
    }
  }

  /// Checks if there is any active exercise currently
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
      debugPrint('Error detecting activity from Samsung Health: $e');
      return null;
    }
  }
  
  /// Specifically checks if the user is walking based on step data
  Future<bool> isWalking() async {
    try {
      final now = DateTime.now();
      final fiveMinutesAgo = now.subtract(const Duration(minutes: 5));
      
      // Get step count for the last 5 minutes
      final stepCount = await SamsungHealthHandler.readStepCount(fiveMinutesAgo, now);
      
      // If more than 20 steps in the last 5 minutes, consider it walking
      return stepCount > 20;
    } catch (e) {
      debugPrint('Error checking if walking from Samsung Health: $e');
      return false;
    }
  }
  
  /// Gets activity data for walking, running, cycling
  Future<Map<String, dynamic>?> getActivityData(String activityType, DateTime startTime, DateTime endTime) async {
    try {
      switch (activityType.toLowerCase()) {
        case 'walking':
        case 'running':
        case 'cycling':
          final exercises = await SamsungHealthHandler.readExercises(startTime, endTime);
          final relevantExercises = exercises.where((ex) => 
            _mapExerciseType(ex.exerciseType).toLowerCase() == activityType.toLowerCase()
          ).toList();
          
          if (relevantExercises.isNotEmpty) {
            final exercise = relevantExercises.first;
            return {
              'type': activityType,
              'duration': exercise.duration?.inSeconds ?? 0,
              'distance': exercise.distance ?? 0,
              'calories': exercise.calorie ?? 0,
              'startTime': exercise.startTime.toIso8601String(),
              'endTime': exercise.endTime?.toIso8601String(),
            };
          }
          break;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting activity data from Samsung Health: $e');
      return null;
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

  /// Maps Samsung Health exercise types to readable names
  String _mapExerciseType(int exerciseType) {
    switch (exerciseType) {
      case 1001: return 'Walking';
      case 1002: return 'Running';
      case 1003: return 'Cycling';
      case 1004: return 'Swimming';
      case 1005: return 'Strength Training';
      case 1006: return 'Yoga';
      case 1007: return 'Basketball';
      case 1008: return 'Football';
      case 1009: return 'Tennis';
      case 1010: return 'Golf';
      default: return 'Unknown Exercise ($exerciseType)';
    }
  }
}