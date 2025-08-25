import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'google_fit_service.dart';
import 'samsung_health_service.dart';

typedef ActivityDetectionCallback = void Function(String activityType, bool isActive);

class HealthService {
  bool _isSamsung = false;
  GoogleFitService? _googleFitService;
  SamsungHealthService? _samsungHealthService;
  
  // Singleton pattern
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  /// Initialize the health service by detecting device type
  Future<void> initialize() async {
    await _detectDevice();
    
    if (_isSamsung) {
      _samsungHealthService = SamsungHealthService();
      debugPrint('Initialized Samsung Health Service');
    } else {
      _googleFitService = GoogleFitService();
      debugPrint('Initialized Google Fit Service');
    }
  }

  /// Detect if device is Samsung
  Future<void> _detectDevice() async {
    if (Platform.isAndroid) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        _isSamsung = androidInfo.manufacturer.toLowerCase().contains('samsung');
        debugPrint('Device detected: ${androidInfo.manufacturer} (Samsung: $_isSamsung)');
      } catch (e) {
        debugPrint('Error detecting device type: $e');
        _isSamsung = false;
      }
    } else {
      _isSamsung = false;
    }
  }

  /// Request health permissions based on device type
  static Future<bool> requestPermission({bool? preferSamsung}) async {
    final instance = HealthService();
    if (!instance._hasBeenInitialized) {
      debugPrint('HealthService: Initializing HealthService for permission request...');
      await instance.initialize();
    }
    
    final shouldUseSamsung = preferSamsung ?? instance._isSamsung;
    debugPrint('HealthService: Requesting permissions - shouldUseSamsung: $shouldUseSamsung, deviceIsSamsung: ${instance._isSamsung}');
    
    bool result;
    if (shouldUseSamsung) {
      debugPrint('HealthService: Requesting Samsung Health permissions');
      try {
        result = await SamsungHealthService.requestPermission();
        debugPrint('HealthService: Samsung Health permission result: $result');
        
        if (!result) {
          debugPrint('HealthService: Samsung Health failed, trying Google Fit fallback...');
          result = await GoogleFitService.requestPermission(preferSamsung: false);
          debugPrint('HealthService: Google Fit fallback result: $result');
        }
      } catch (e) {
        debugPrint('HealthService: Error with Samsung Health, falling back to Google Fit: $e');
        result = await GoogleFitService.requestPermission(preferSamsung: false);
        debugPrint('HealthService: Google Fit fallback result: $result');
      }
    } else {
      debugPrint('HealthService: Requesting Google Fit permissions');
      result = await GoogleFitService.requestPermission(preferSamsung: false);
      debugPrint('HealthService: Google Fit permission result: $result');
    }
    
    debugPrint('HealthService: Final permission request result: $result');
    return result;
  }

  bool get _hasBeenInitialized => _isSamsung ? _samsungHealthService != null : _googleFitService != null;

  /// Check if all health permissions are granted
  Future<bool> checkAllPermissionsGranted() async {
    if (!_hasBeenInitialized) {
      debugPrint('HealthService not initialized, initializing now...');
      await initialize();
    }
    
    debugPrint('HealthService: Checking health permissions - isSamsung: $_isSamsung');
    
    if (_isSamsung && _samsungHealthService != null) {
      try {
        final granted = await _samsungHealthService!.checkAllPermissionsGranted();
        debugPrint('HealthService: Samsung Health permissions check result: $granted');
        
        if (!granted) {
          debugPrint('HealthService: Samsung Health permissions not granted, checking if we should fallback to Google Fit');
          // If Samsung Health permissions fail, try Google Fit as fallback
          debugPrint('HealthService: Attempting Google Fit fallback...');
          _googleFitService = GoogleFitService();
          final googleFitGranted = await _googleFitService!.checkAllPermissionsGranted();
          debugPrint('HealthService: Google Fit fallback result: $googleFitGranted');
          return googleFitGranted;
        }
        
        return granted;
      } catch (e) {
        debugPrint('HealthService: Error checking Samsung Health permissions: $e');
        debugPrint('HealthService: Falling back to Google Fit due to Samsung Health error');
        
        // Fallback to Google Fit on error
        _googleFitService = GoogleFitService();
        final googleFitGranted = await _googleFitService!.checkAllPermissionsGranted();
        debugPrint('HealthService: Google Fit fallback result: $googleFitGranted');
        return googleFitGranted;
      }
    } else if (_googleFitService != null) {
      final granted = await _googleFitService!.checkAllPermissionsGranted();
      debugPrint('HealthService: Google Fit permissions check result: $granted');
      return granted;
    }
    
    debugPrint('HealthService: No health service available');
    return false;
  }

  /// Get current detailed exercise information
  Future<Map<String, dynamic>?> getCurrentExerciseDetailed() async {
    if (!_hasBeenInitialized) {
      await initialize();
    }
    
    if (_isSamsung && _samsungHealthService != null) {
      return await _samsungHealthService!.getCurrentExerciseDetailed();
    } else if (_googleFitService != null) {
      return await _googleFitService!.getCurrentExerciseDetailed();
    }
    
    return null;
  }

  /// Get current active exercise type (walking, running, etc.)
  Future<String?> getCurrentActiveExerciseType() async {
    if (!_hasBeenInitialized) {
      await initialize();
    }
    
    if (_isSamsung && _samsungHealthService != null) {
      return await _samsungHealthService!.getCurrentActiveExerciseType();
    } else if (_googleFitService != null) {
      return await _googleFitService!.getCurrentActiveExerciseType();
    }
    
    return null;
  }

  /// Check if user is currently walking
  Future<bool> isWalking() async {
    if (!_hasBeenInitialized) {
      await initialize();
    }
    
    if (_isSamsung && _samsungHealthService != null) {
      return await _samsungHealthService!.isWalking();
    } else if (_googleFitService != null) {
      return await _googleFitService!.isWalking();
    }
    
    return false;
  }

  /// Get specific activity data (walking, running, cycling)
  Future<Map<String, dynamic>?> getActivityData(String activityType, DateTime startTime, DateTime endTime) async {
    if (!_hasBeenInitialized) {
      await initialize();
    }
    
    if (_isSamsung && _samsungHealthService != null) {
      return await _samsungHealthService!.getActivityData(activityType, startTime, endTime);
    }
    
    // For Google Fit, we'll use the existing health package functionality
    // This is a simplified implementation - in a real app you'd want more detailed data
    final currentExercise = await getCurrentExerciseDetailed();
    if (currentExercise != null && 
        currentExercise['exerciseType']?.toLowerCase() == activityType.toLowerCase()) {
      return {
        'type': activityType,
        'duration': (DateTime.now().difference(DateTime.parse(currentExercise['startTime']))).inSeconds,
        'startTime': currentExercise['startTime'],
        'endTime': currentExercise['endTime'],
        'source': 'Google Fit',
      };
    }
    
    return null;
  }

  /// Start monitoring user activity
  void startActivityMonitoring({ActivityDetectionCallback? callback}) {
    if (!_hasBeenInitialized) {
      // Initialize asynchronously and then start monitoring
      initialize().then((_) => _startMonitoring(callback));
      return;
    }
    
    _startMonitoring(callback);
  }

  void _startMonitoring(ActivityDetectionCallback? callback) {
    if (_isSamsung && _samsungHealthService != null) {
      _samsungHealthService!.startActivityMonitoring(callback: callback);
    } else if (_googleFitService != null) {
      _googleFitService!.startActivityMonitoring(callback: callback);
    }
  }

  /// Stop monitoring user activity
  void stopActivityMonitoring() {
    if (_isSamsung && _samsungHealthService != null) {
      _samsungHealthService!.stopActivityMonitoring();
    } else if (_googleFitService != null) {
      _googleFitService!.stopActivityMonitoring();
    }
  }

  /// Get the service type being used
  String get serviceType => _isSamsung ? 'Samsung Health' : 'Google Fit';

  /// Check if using Samsung Health
  bool get isSamsung => _isSamsung;
}