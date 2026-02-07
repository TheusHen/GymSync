import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';

class ForegroundWorkoutService {
  static const String _channelId = 'workout_tracking_channel';
  static const String _channelName = 'Workout Tracking';

  static final ForegroundWorkoutService _instance = ForegroundWorkoutService._internal();
  factory ForegroundWorkoutService() => _instance;
  ForegroundWorkoutService._internal();

  bool _isRunning = false;

  static void initialize() {
    FlutterForegroundTask.init(
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
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> startWorkoutTracking(String activity) async {
    if (_isRunning) {
      await stopWorkoutTracking();
    }

    if (!await FlutterForegroundTask.canDrawOverlays) {
      await FlutterForegroundTask.openSystemAlertWindowSettings();
    }

    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'GymSync Active',
      notificationText: 'Tracking $activity workout',
      callback: _foregroundTaskCallback,
    );

    final isStarted = result == ServiceRequestResult.success;

    if (isStarted) {
      _isRunning = true;
      debugPrint('Foreground workout tracking started for: $activity');
    }

    return isStarted;
  }

  Future<bool> stopWorkoutTracking() async {
    if (!_isRunning) return true;

    final result = await FlutterForegroundTask.stopService();
    final isStopped = result == ServiceRequestResult.success;
    if (isStopped) {
      _isRunning = false;
      debugPrint('Foreground workout tracking stopped');
    }

    return isStopped;
  }

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

  bool get isRunning => _isRunning;

  static Future<void> onBoot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activity = prefs.getString('current_activity');
      final startTime = prefs.getInt('workout_start_time');

      if (activity != null && startTime != null) {
        debugPrint('Restoring workout on boot: $activity');
        final instance = ForegroundWorkoutService();
        await instance.startWorkoutTracking(activity);
      }
    } catch (e) {
      debugPrint('Error restoring workout on boot: $e');
    }
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}

@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_WorkoutTaskHandler());
}

class _WorkoutTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Workout tracking service started at $timestamp');
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _updateWorkoutStatus();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    debugPrint('Workout tracking service destroyed at $timestamp');
  }

  Future<void> _updateWorkoutStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activity = prefs.getString('current_activity');
      final startTime = prefs.getInt('workout_start_time');

      if (activity != null && startTime != null) {
        final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
        final elapsedDuration = Duration(milliseconds: elapsed);

        // Use heartbeat instead of start() to keep session alive
        await BackendService.heartbeat();

        final formattedTime = _formatElapsed(elapsedDuration);
        await FlutterForegroundTask.updateService(
          notificationTitle: 'GymSync - $formattedTime',
          notificationText: 'Tracking $activity workout',
        );
      }
    } catch (e) {
      debugPrint('Error updating workout status: $e');
    }
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }
}
