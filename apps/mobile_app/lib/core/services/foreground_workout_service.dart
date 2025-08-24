import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';

/// Foreground service for continuous workout tracking
/// This ensures the workout timer continues running even when app is backgrounded
class ForegroundWorkoutService {
  static const String _channelId = 'workout_tracking_channel';
  static const String _channelName = 'Workout Tracking';

  // Singleton pattern
  static final ForegroundWorkoutService _instance = ForegroundWorkoutService._internal();
  factory ForegroundWorkoutService() => _instance;
  ForegroundWorkoutService._internal();

  bool _isRunning = false;
  ReceivePort? _receivePort;

  /// Initialize the foreground service
  static Future<void> initialize() async {
    await FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: _channelName,
        channelDescription: 'Notification channel for workout tracking',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000), // Update every 5 seconds
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start foreground workout tracking
  Future<bool> startWorkoutTracking(String activity) async {
    if (_isRunning) {
      await stopWorkoutTracking();
    }

    // Request permissions
    if (!await FlutterForegroundTask.canDrawOverlays) {
      final isGranted = await FlutterForegroundTask.openSystemAlertWindowSettings();
      if (!isGranted) {
        debugPrint('System alert window permission denied');
      }
    }

    // Request notification permission
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Start foreground service
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'GymSync Active',
      notificationText: 'Tracking $activity workout',
      callback: _foregroundTaskCallback,
    );

    // FIX: ServiceRequestResult.success may not exist; use ServiceResult.success instead or compare result with expected value.
    // Check what result returns: it's likely a bool, enum, or int, depending on flutter_foreground_task version
    final isStarted = result == ServiceResult.success; // <-- fix

    if (isStarted) {
      _isRunning = true;
      debugPrint('Foreground workout tracking started for: $activity');
    }

    return isStarted;
  }

  /// Stop foreground workout tracking
  Future<bool> stopWorkoutTracking() async {
    if (!_isRunning) return true;

    final result = await FlutterForegroundTask.stopService();

    // FIX: ServiceRequestResult.success may not exist; use ServiceResult.success instead or compare result with expected value.
    final isStopped = result == ServiceResult.success; // <-- fix
    if (isStopped) {
      _isRunning = false;
      _receivePort?.close();
      _receivePort = null;
      debugPrint('Foreground workout tracking stopped');
    }

    return isStopped;
  }

  /// Update notification during workout
  Future<void> updateWorkoutNotification({
    required String activity,
    required Duration elapsed,
  }) async {
    if (!_isRunning) return;

    final String formattedTime = _formatElapsed(elapsed);
    await FlutterForegroundTask.updateService(
      notificationTitle: 'GymSync - $formattedTime',
      notificationText: 'Tracking $activity workout',
    );
  }

  /// Check if service is running
  bool get isRunning => _isRunning;

  /// Format elapsed time
  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}

/// Foreground task callback
/// This runs in the foreground service context
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_WorkoutTaskHandler());
}

/// Task handler for workout tracking
class _WorkoutTaskHandler extends TaskHandler {
  int _updateCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Workout tracking service started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateCount++;

    // Update workout status every 5 seconds (as configured)
    _updateWorkoutStatus();

    // Send heartbeat to main isolate if needed
    FlutterForegroundTask.sendDataToMain({
      'timestamp': timestamp.millisecondsSinceEpoch,
      'updateCount': _updateCount,
    });
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Workout tracking service destroyed at $timestamp');
  }

  /// Update workout status in background
  Future<void> _updateWorkoutStatus() async {
    try {
      // Get current workout status
      final prefs = await SharedPreferences.getInstance();
      final activity = prefs.getString('current_activity');
      final startTime = prefs.getInt('workout_start_time');

      if (activity != null && startTime != null) {
        // Calculate elapsed time
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        final elapsedDuration = Duration(milliseconds: elapsed);

        // Update backend status
        await BackendService.start(activity);

        // Update notification
        final formattedTime = _formatElapsed(elapsedDuration);
        await FlutterForegroundTask.updateService(
          notificationTitle: 'GymSync - $formattedTime',
          notificationText: 'Tracking $activity workout',
        );

        debugPrint('Workout status updated: $activity, elapsed: $formattedTime');
      }
    } catch (e) {
      debugPrint('Error updating workout status: $e');
    }
  }

  /// Format elapsed time
  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}
