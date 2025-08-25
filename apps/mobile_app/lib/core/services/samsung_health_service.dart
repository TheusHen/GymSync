import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// Note: This now uses MethodChannel to communicate with Samsung Health SDK
typedef ActivityDetectionCallback = void Function(String activityType, bool isActive);

class SamsungHealthService {
  Timer? _activityMonitorTimer;
  ActivityDetectionCallback? onActivityDetected;
  
  static const MethodChannel _channel = MethodChannel('samsung_health');
  
  // Singleton pattern
  static final SamsungHealthService _instance = SamsungHealthService._internal();
  factory SamsungHealthService() => _instance;
  SamsungHealthService._internal();

  /// Request Samsung Health permissions using Samsung Health SDK
  static Future<bool> requestPermission() async {
    try {
      debugPrint('SamsungHealthService: Starting permission request...');
      
      // First check and request basic Android permissions
      final permissions = [
        Permission.activityRecognition,
        Permission.sensors,
        Permission.locationWhenInUse,
      ];
      
      debugPrint('SamsungHealthService: Requesting basic Android permissions...');
      final statuses = await permissions.request();
      final basicPermissionsGranted = statuses.values.every((status) => status.isGranted);
      
      debugPrint('SamsungHealthService: Basic permissions result: $basicPermissionsGranted');
      debugPrint('SamsungHealthService: Permission details: ${statuses.map((key, value) => MapEntry(key.toString(), value.toString()))}');
      
      if (!basicPermissionsGranted) {
        debugPrint('SamsungHealthService: Basic permissions not granted, failing');
        return false;
      }
      
      // Now request Samsung Health specific permissions via MethodChannel
      debugPrint('SamsungHealthService: Requesting Samsung Health permissions via MethodChannel...');
      try {
        final result = await _channel.invokeMethod('requestPermission');
        final granted = result as bool? ?? false;
        debugPrint('SamsungHealthService: Samsung Health permission result: $granted');
        return granted;
      } on PlatformException catch (e) {
        debugPrint('SamsungHealthService: PlatformException during Samsung Health permission request: ${e.code} - ${e.message}');
        
        // Check specific error codes
        if (e.code == 'SAMSUNG_HEALTH_NOT_INSTALLED') {
          debugPrint('SamsungHealthService: Samsung Health not installed, falling back to basic permissions');
          return basicPermissionsGranted; // Return true if basic permissions work
        } else if (e.code == 'SAMSUNG_HEALTH_DISABLED') {
          debugPrint('SamsungHealthService: Samsung Health disabled');
          return false;
        } else {
          debugPrint('SamsungHealthService: Unknown Samsung Health error, falling back to basic permissions');
          return basicPermissionsGranted;
        }
      } catch (e) {
        debugPrint('SamsungHealthService: Unexpected error during Samsung Health permission request: $e');
        return basicPermissionsGranted; // Fallback to basic permissions
      }
    } catch (e) {
      debugPrint('SamsungHealthService: Error in requestPermission: $e');
      return false;
    }
  }

  /// Check if Samsung Health permissions are granted
  Future<bool> checkAllPermissionsGranted() async {
    try {
      debugPrint('SamsungHealthService: Checking permissions...');
      
      // First check basic Android permissions
      final activity = await Permission.activityRecognition.isGranted;
      final sensors = await Permission.sensors.isGranted;
      final location = await Permission.locationWhenInUse.isGranted;
      
      debugPrint('SamsungHealthService: Basic permissions check: activity=$activity, sensors=$sensors, location=$location');
      
      if (!activity || !sensors || !location) {
        debugPrint('SamsungHealthService: Basic permissions not granted');
        return false;
      }
      
      // Check Samsung Health specific permissions via MethodChannel
      try {
        debugPrint('SamsungHealthService: Checking Samsung Health permissions via MethodChannel...');
        final result = await _channel.invokeMethod('checkPermissions');
        final granted = result as bool? ?? false;
        debugPrint('SamsungHealthService: Samsung Health permissions check result: $granted');
        return granted;
      } on PlatformException catch (e) {
        debugPrint('SamsungHealthService: PlatformException during permission check: ${e.code} - ${e.message}');
        
        // Handle specific platform exceptions
        if (e.code == 'SAMSUNG_HEALTH_NOT_INSTALLED') {
          debugPrint('SamsungHealthService: Samsung Health not installed, assuming basic permissions are sufficient');
          return true; // If Samsung Health is not installed, we can't use it anyway
        } else if (e.code == 'NOT_CONNECTED') {
          debugPrint('SamsungHealthService: Not connected to Samsung Health, trying to reconnect...');
          
          // Try to request permission which will also connect
          final reconnected = await requestPermission();
          debugPrint('SamsungHealthService: Reconnection result: $reconnected');
          return reconnected;
        } else {
          debugPrint('SamsungHealthService: Samsung Health error, falling back to basic permissions');
          return true; // Fallback - assume basic permissions are enough
        }
      } catch (e) {
        debugPrint('SamsungHealthService: Unexpected error during permission check: $e');
        return true; // Fallback - assume basic permissions are enough
      }
    } catch (e) {
      debugPrint('SamsungHealthService: Error in checkAllPermissionsGranted: $e');
      return false;
    }
  }

  /// Check if Samsung Health is connected
  Future<bool> isConnected() async {
    try {
      final result = await _channel.invokeMethod('isConnected');
      final connected = result as bool? ?? false;
      debugPrint('SamsungHealthService: Connection status: $connected');
      return connected;
    } on PlatformException catch (e) {
      debugPrint('SamsungHealthService: PlatformException checking connection: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('SamsungHealthService: Error checking connection: $e');
      return false;
    }
  }

  /// Returns the current detailed exercise, if there is one in progress
  Future<Map<String, dynamic>?> getCurrentExerciseDetailed() async {
    try {
      debugPrint('SamsungHealthService: getCurrentExerciseDetailed called');
      
      // For now, this is still a placeholder as we need to implement
      // exercise data retrieval in the native side
      final connected = await isConnected();
      if (!connected) {
        debugPrint('SamsungHealthService: Not connected, cannot get exercise data');
        return null;
      }
      
      // TODO: Implement exercise data retrieval via MethodChannel
      debugPrint('SamsungHealthService: Exercise data retrieval not yet implemented');
      return null;
    } catch (e) {
      debugPrint('SamsungHealthService: Error getting current exercise: $e');
      return null;
    }
  }

  /// Checks if there is any active exercise currently
  Future<String?> getCurrentActiveExerciseType() async {
    try {
      debugPrint('SamsungHealthService: getCurrentActiveExerciseType called');
      
      // First try to get detailed exercise info
      final exercise = await getCurrentExerciseDetailed();
      if (exercise != null) {
        return exercise['exerciseType'];
      }
      
      // Fallback to basic walking detection
      if (await isWalking()) {
        return "Walking";
      }
      
      return null;
    } catch (e) {
      debugPrint('SamsungHealthService: Error detecting active exercise: $e');
      return null;
    }
  }
  
  /// Simplified walking detection - placeholder implementation
  Future<bool> isWalking() async {
    try {
      debugPrint('SamsungHealthService: isWalking called (placeholder implementation)');
      
      final connected = await isConnected();
      if (!connected) {
        debugPrint('SamsungHealthService: Not connected, cannot detect walking');
        return false;
      }
      
      // TODO: Implement actual step detection via Samsung Health SDK
      // For now, this is a placeholder
      return false;
    } catch (e) {
      debugPrint('SamsungHealthService: Error checking if walking: $e');
      return false;
    }
  }
  
  /// Gets activity data for walking, running, cycling
  Future<Map<String, dynamic>?> getActivityData(String activityType, DateTime startTime, DateTime endTime) async {
    try {
      debugPrint('SamsungHealthService: getActivityData called for $activityType');
      
      final connected = await isConnected();
      if (!connected) {
        debugPrint('SamsungHealthService: Not connected, cannot get activity data');
        return null;
      }
      
      // TODO: Implement activity data retrieval via MethodChannel
      debugPrint('SamsungHealthService: Activity data retrieval not yet implemented');
      return null;
    } catch (e) {
      debugPrint('SamsungHealthService: Error getting activity data: $e');
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
      try {
        debugPrint('SamsungHealthService: Activity monitoring tick');
        
        final activityType = await getCurrentActiveExerciseType();
        if (activityType != null && onActivityDetected != null) {
          debugPrint('SamsungHealthService: Detected activity: $activityType');
          onActivityDetected!(activityType, true);
        }
      } catch (e) {
        debugPrint('SamsungHealthService: Error in activity monitoring: $e');
      }
    });
    
    debugPrint('SamsungHealthService: Activity monitoring started');
  }
  
  /// Stops continuous monitoring of user activity
  void stopActivityMonitoring() {
    _activityMonitorTimer?.cancel();
    _activityMonitorTimer = null;
    debugPrint('SamsungHealthService: Activity monitoring stopped');
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