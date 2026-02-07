import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/circular_timer.dart';
import '../widgets/discord_status_indicator.dart';
import '../widgets/animated_button.dart';
import '../core/services/backend_service.dart';
import '../core/services/health_service.dart';
import '../core/services/notification_service.dart';
import '../core/services/background_location_service.dart';
import '../core/services/foreground_workout_service.dart';
import '../core/services/workout_stats_service.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool running = false;
  bool paused = false;
  Duration elapsed = Duration.zero;
  String activity = 'unknown';
  String lastSession = '00:00 - unknown';
  LatLng? gymLocation;
  static const double gymRadiusMeters = 35.0;
  bool inGym = false;
  bool locationChecked = false;
  Timer? _locationTimer;
  Timer? _statusTimer;
  Duration lastElapsed = Duration.zero;
  String lastActivity = 'unknown';
  static bool _backgroundStarted = false;

  @override
  void initState() {
    super.initState();
    _setupApp();
  }

  Future<void> _setupApp() async {
    await _requestPermissions();
    await NotificationService().init();
    NotificationService().onAction = _onNotificationAction;
    await _startBackgroundMode();
    await _loadGymLocation();
    await _checkIfInGym();
    await _loadBackendStatus();
    await _restoreWorkoutState();
    await _checkAndRequestHealthPermissions();

    // Start background services only once
    if (!_backgroundStarted) {
      _backgroundStarted = true;
      await BackgroundLocationService().startLocationMonitoring();
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }

    if (inGym) {
      _startGymFlowIfNeeded();
    } else {
      _checkAndStartActiveExercise();
    }
    _startLocationMonitoring();
    _startActivityMonitoring();
  }

  Future<void> _restoreWorkoutState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentActivity = prefs.getString('current_activity');
      final startTime = prefs.getInt('workout_start_time');
      final pauseTime = prefs.getInt('workout_pause_time');

      if (currentActivity != null && startTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;

        if (pauseTime != null) {
          final pausedElapsed = Duration(milliseconds: pauseTime - startTime);
          setState(() {
            activity = currentActivity;
            running = false;
            paused = true;
            elapsed = pausedElapsed;
          });
          _startReducedLocationMonitoring();
        } else {
          final elapsedMillis = now - startTime;
          setState(() {
            activity = currentActivity;
            running = true;
            paused = false;
            elapsed = Duration(milliseconds: elapsedMillis);
          });
          _startStatusUpdates();
        }
      }
    } catch (e) {
      debugPrint('Error restoring workout state: $e');
    }
  }

  Future<void> _checkAndRequestHealthPermissions() async {
    try {
      final healthService = HealthService();
      final hasPermissions = await healthService.checkAllPermissionsGranted();
      if (!hasPermissions) {
        final granted = await HealthService.requestPermission();
        if (!granted && mounted) {
          _showHealthPermissionDialog();
        }
      }
    } catch (e) {
      debugPrint('Error checking health permissions: $e');
    }
  }

  void _showHealthPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Health Access Required'),
          content: const Text(
            'GymSync needs access to your health data to automatically detect exercises. '
            'Please grant permissions in your device settings:\n\n'
            '1. Go to Settings\n'
            '2. Find Apps > GymSync\n'
            '3. Enable Health/Fitness permissions\n'
            '4. Return to the app',
          ),
          actions: [
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                Navigator.of(ctx).pop();
                openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Try Again'),
              onPressed: () {
                Navigator.of(ctx).pop();
                _checkAndRequestHealthPermissions();
              },
            ),
            TextButton(
              child: const Text('Later'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        );
      },
    );
  }

  void _startActivityMonitoring() async {
    final granted = await HealthService.requestPermission();
    if (!granted) {
      debugPrint('Health permissions not granted, skipping activity monitoring');
      return;
    }
    HealthService().startActivityMonitoring(
      callback: (activityType, isActive) {
        if (!inGym && (!running || activity != activityType) && isActive) {
          _startActivityTracking(activityType);
        }
      },
    );
  }

  void _startActivityTracking(String activityType) async {
    if (inGym || (running && activity == activityType)) return;
    try {
      await BackendService.start(activityType);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_activity', activityType);
      await prefs.setInt('workout_start_time', DateTime.now().millisecondsSinceEpoch);

      setState(() {
        activity = activityType;
        running = true;
        elapsed = Duration.zero;
      });

      await ForegroundWorkoutService().startWorkoutTracking(activityType);
      _startStatusUpdates();
      _maybeUpdateNotification();

      if (activityType == "Walking") {
        _showCustomNotification(
          'Walking Detected',
          'GymSync is now tracking your walking activity.',
        );
      }
    } catch (_) {}
  }

  Future<void> _loadBackendStatus() async {
    final data = await BackendService.getStatus();
    if (data != null) {
      setState(() {
        // Backend returns: { activity, time, paused }
        final backendActivity = data['activity'];
        final backendTime = data['time'];
        final backendPaused = data['paused'];

        if (backendActivity != null) {
          activity = backendActivity;
          final seconds = (backendTime is int) ? backendTime : (int.tryParse('$backendTime') ?? 0);
          elapsed = Duration(seconds: seconds);
          if (backendPaused == true) {
            running = false;
            paused = true;
          } else {
            running = true;
            paused = false;
          }
        }
      });
    }
  }

  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.location.isDenied) {
      await Permission.location.request();
    }
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }
    if (await Permission.sensors.isDenied) {
      await Permission.sensors.request();
    }
  }

  Future<void> _startBackgroundMode() async {
    try {
      final hasPermissions = await FlutterBackground.hasPermissions;
      if (!hasPermissions) {
        await FlutterBackground.initialize(
          androidConfig: const FlutterBackgroundAndroidConfig(
            notificationTitle: "GymSync Active",
            notificationText: "Tracking your workout and location in the background.",
            notificationImportance: AndroidNotificationImportance.normal,
            enableWifiLock: true,
          ),
        );
      }
      await FlutterBackground.enableBackgroundExecution();
    } catch (e) {
      debugPrint('Background execution setup failed: $e');
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    NotificationService().cancel();
    HealthService().stopActivityMonitoring();
    super.dispose();
  }

  void _onNotificationAction(String action) {
    if (action == 'pause') {
      onPause();
    } else if (action == 'stop') {
      onStop();
    }
  }

  void _maybeUpdateNotification() {
    if (!running || !NotificationService().enabled) {
      NotificationService().cancel();
      return;
    }
    NotificationService().show(
      elapsed: _formatElapsed(elapsed),
      activity: activity,
    );
  }

  void _startLocationMonitoring() {
    if (paused) return;
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (paused) return;
      await _checkIfInGym();
      if (inGym && !running) {
        if (paused) {
          await _autoResumeFromGym();
        } else {
          _startGymFlowIfNeeded();
        }
      } else if (!inGym && running && activity == "Gym") {
        await _autoPauseFromGymExit();
      }
    });
  }

  void _stopLocationMonitoring() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<void> _autoPauseFromGymExit() async {
    if (paused) return;
    debugPrint('Auto-pausing workout: left gym');
    await _pauseWorkout();
    _showCustomNotification(
      'Workout Paused',
      'You left the gym. Your workout is paused and will resume when you return.',
    );
    _stopLocationMonitoring();
    _startReducedLocationMonitoring();
  }

  Future<void> _autoResumeFromGym() async {
    if (!paused) return;
    debugPrint('Auto-resuming workout: returned to gym');
    await _resumeWorkout();
    _showCustomNotification(
      'Workout Resumed',
      'Welcome back! Your workout has resumed from where you left off.',
    );
    _startLocationMonitoring();
  }

  void _startReducedLocationMonitoring() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!paused) return;
      await _checkIfInGym();
      if (inGym) {
        await _autoResumeFromGym();
      }
    });
  }

  Future<void> _startGymFlowIfNeeded() async {
    if (running && activity == "Gym") return;
    if (running && activity != "Gym") {
      await BackendService.stop();
      setState(() {
        lastSession = '${_formatElapsed(elapsed)} - $activity';
      });
    }
    try {
      await BackendService.start("Gym");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_activity', "Gym");
      await prefs.setInt('workout_start_time', DateTime.now().millisecondsSinceEpoch);

      setState(() {
        activity = "Gym";
        running = true;
        elapsed = Duration.zero;
      });

      await ForegroundWorkoutService().startWorkoutTracking("Gym");
      _startStatusUpdates();
      _maybeUpdateNotification();
    } catch (_) {
      Future.delayed(const Duration(seconds: 5), () {
        if (inGym && (!running || activity != "Gym")) {
          _startGymFlowIfNeeded();
        }
      });
    }
  }

  /// Status update timer: uses heartbeat() instead of start() to keep session alive.
  /// Sends heartbeat every 10 seconds instead of every 1 second.
  void _startStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!running) return;

      // Update elapsed time locally
      await _synchronizeElapsedTime();
      _maybeUpdateNotification();

      // Update foreground service notification
      if (ForegroundWorkoutService().isRunning) {
        await ForegroundWorkoutService().updateWorkoutNotification(
          activity: activity,
          elapsed: elapsed,
        );
      }
    });

    // Separate heartbeat timer - every 30 seconds to keep backend alive
    _startHeartbeatTimer();
  }

  Timer? _heartbeatTimer;

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!running) return;
      await BackendService.heartbeat();
    });
  }

  Future<void> _synchronizeElapsedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startTime = prefs.getInt('workout_start_time');

      if (startTime != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final calculatedElapsed = Duration(milliseconds: now - startTime);

        if ((calculatedElapsed.inSeconds - elapsed.inSeconds).abs() > 2) {
          setState(() {
            elapsed = calculatedElapsed;
          });
        } else {
          setState(() {
            elapsed += const Duration(seconds: 1);
          });
        }
      } else {
        setState(() {
          elapsed += const Duration(seconds: 1);
        });
      }
    } catch (e) {
      debugPrint('Error synchronizing elapsed time: $e');
      setState(() {
        elapsed += const Duration(seconds: 1);
      });
    }
  }

  void _stopStatusUpdates() {
    _statusTimer?.cancel();
    _heartbeatTimer?.cancel();
  }

  Future<void> _loadGymLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('gym_lat');
    final lng = prefs.getDouble('gym_lng');
    setState(() {
      if (lat != null && lng != null) {
        gymLocation = LatLng(lat, lng);
      } else {
        gymLocation = null;
      }
      locationChecked = true;
    });
  }

  Future<void> _checkIfInGym() async {
    if (gymLocation == null) {
      setState(() {
        inGym = false;
        locationChecked = true;
      });
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );
      final Distance distance = Distance();
      final double dist = distance(
        LatLng(pos.latitude, pos.longitude),
        gymLocation!,
      );
      final bool wasInGym = inGym;
      final bool nowInGym = dist <= gymRadiusMeters;
      setState(() {
        inGym = nowInGym;
        locationChecked = true;
      });
      if (!wasInGym && nowInGym) {
        _showGymArrivalNotification();
      }
    } catch (_) {
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null) {
          final Distance distance = Distance();
          final double dist = distance(
            LatLng(lastPos.latitude, lastPos.longitude),
            gymLocation!,
          );
          setState(() {
            inGym = dist <= gymRadiusMeters;
            locationChecked = true;
          });
        } else {
          setState(() {
            locationChecked = true;
          });
        }
      } catch (_) {
        setState(() {
          locationChecked = true;
        });
      }
    }
  }

  void _showGymArrivalNotification() {
    if (!NotificationService().enabled) return;
    _showCustomNotification(
      'Welcome to the Gym!',
      'Your workout timer has started automatically.',
    );
  }

  Future<void> _showCustomNotification(String title, String body) async {
    final FlutterLocalNotificationsPlugin plugin =
        FlutterLocalNotificationsPlugin();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gym_arrival_channel',
      'Gym Arrival',
      channelDescription: 'Notifications when you arrive at the gym',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    await plugin.show(
      2,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _checkAndStartActiveExercise() async {
    if (inGym) return;
    final granted = await HealthService.requestPermission();
    if (!granted) return;
    final exerciseType = await HealthService().getCurrentActiveExerciseType();
    if (exerciseType != null && !running) {
      await BackendService.start(exerciseType);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_activity', exerciseType);
      await prefs.setInt('workout_start_time', DateTime.now().millisecondsSinceEpoch);

      setState(() {
        activity = exerciseType;
        running = true;
        elapsed = Duration.zero;
      });

      await ForegroundWorkoutService().startWorkoutTracking(exerciseType);
      _startStatusUpdates();
      _maybeUpdateNotification();
    }
  }

  Future<void> _pauseWorkout() async {
    if (!running || paused) return;

    await BackendService.pause();
    setState(() {
      paused = true;
      running = false;
    });
    _stopStatusUpdates();
    NotificationService().cancel();
    await ForegroundWorkoutService().stopWorkoutTracking();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workout_pause_time', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _resumeWorkout() async {
    if (!paused) return;

    await BackendService.resume();
    setState(() {
      paused = false;
      running = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final pauseTime = prefs.getInt('workout_pause_time');
    final currentStartTime = prefs.getInt('workout_start_time');

    if (pauseTime != null && currentStartTime != null) {
      final pauseDuration = DateTime.now().millisecondsSinceEpoch - pauseTime;
      final newStartTime = currentStartTime + pauseDuration;
      await prefs.setInt('workout_start_time', newStartTime);
      await prefs.remove('workout_pause_time');
    }

    await ForegroundWorkoutService().startWorkoutTracking(activity);
    _startStatusUpdates();
    _maybeUpdateNotification();
  }

  void onPause() async {
    await _pauseWorkout();
    _stopLocationMonitoring();
    _startReducedLocationMonitoring();
  }

  void onResume() async {
    await _resumeWorkout();
    _startLocationMonitoring();
  }

  void onStop() async {
    await BackendService.stop();
    
    // Record workout statistics
    if (elapsed.inSeconds > 0) {
      await WorkoutStatsService().recordWorkout(
        activityType: activity,
        duration: elapsed,
      );
      debugPrint('Workout recorded: $activity for ${elapsed.inMinutes} minutes');
    }
    
    setState(() {
      running = false;
      paused = false;
      lastSession = '${_formatElapsed(elapsed)} - $activity';
      elapsed = Duration.zero;
    });
    _stopStatusUpdates();
    NotificationService().cancel();
    await ForegroundWorkoutService().stopWorkoutTracking();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_activity');
    await prefs.remove('workout_start_time');
    await prefs.remove('workout_pause_time');

    _startLocationMonitoring();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final bool controlsEnabled = running || paused;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              await _loadGymLocation();
              await _checkIfInGym();
              setState(() {});
            },
          )
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: locationChecked
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircularTimer(
                        running: running && !paused,
                        duration: elapsed,
                        activity: activity,
                      ),
                      const SizedBox(height: 24),
                      if (paused)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Workout Paused',
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedButton(
                            text: (running && !paused) ? 'Pause' : 'Resume',
                            onPressed: controlsEnabled
                                ? ((running && !paused) ? onPause : onResume)
                                : () {},
                            enabled: controlsEnabled,
                          ),
                          const SizedBox(width: 16),
                          AnimatedButton(
                            text: 'Stop',
                            onPressed: controlsEnabled ? onStop : () {},
                            enabled: controlsEnabled,
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        'Last session: $lastSession',
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      const DiscordStatusIndicator(),
                    ],
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
