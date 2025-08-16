import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/circular_timer.dart';
import '../widgets/discord_status_indicator.dart';
import '../widgets/animated_button.dart';
import '../core/services/backend_service.dart';
import '../core/services/google_fit_service.dart';
import '../core/services/notification_service.dart';
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
  Duration elapsed = Duration.zero;
  String activity = 'unknown';
  String lastSession = '00:00 - unknown';
  LatLng? gymLocation;
  static const double gymRadiusMeters = 35.0;
  bool inGym = false;
  bool locationChecked = false;
  Timer? _locationTimer;
  Timer? _statusTimer;
  bool _notifEnabled = true;
  Duration lastElapsed = Duration.zero;
  String lastActivity = 'unknown';
  static bool _backgroundStarted = false;

  @override
  void initState() {
    super.initState();
    _setupApp();
    _ensureBackgroundServiceStarted();
  }

  Future<void> _ensureBackgroundServiceStarted() async {
    if (!_backgroundStarted) {
      _backgroundStarted = true;
      await _requestPermissions();
      await _startBackgroundMode();
      await _loadGymLocation();
      _startPersistentBackgroundLocationMonitor();
      
      // Request to ignore battery optimizations for better background performance
      if (await Permission.ignoreBatteryOptimizations.isDenied) {
        await Permission.ignoreBatteryOptimizations.request();
      }
    }
  }

  void _startPersistentBackgroundLocationMonitor() {
    // Use a more battery-efficient interval for background monitoring
    Timer.periodic(const Duration(seconds: 30), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble('gym_lat');
      final lng = prefs.getDouble('gym_lng');
      if (lat == null || lng == null) return;
      final gymLoc = LatLng(lat, lng);

      try {
        // Use a lower accuracy for background monitoring to save battery
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw TimeoutException('Location request timed out in background');
          },
        );
        
        final Distance distance = Distance();
        final double dist = distance(
          LatLng(pos.latitude, pos.longitude),
          gymLoc,
        );
        final bool inside = dist <= gymRadiusMeters;
        final bool wasInGym = inGym;
        
        // Update the inGym state
        if (mounted) {
          setState(() {
            inGym = inside;
          });
        } else {
          inGym = inside;
        }

        final data = await BackendService.getStatus();
        String currentActivity = data?['status']?['activity'] ?? 'unknown';
        bool isRunning = (data?['status']?['state'] ?? 'paused') == 'active';

        // Start gym activity when arriving at the gym
        if (inside && (!isRunning || currentActivity != "Gym")) {
          await BackendService.start("Gym");
          
          // Show notification when arriving at the gym (transition from outside to inside)
          if (!wasInGym && inside) {
            _showGymArrivalNotification();
          }
        }
        
        // Also check for walking activity when not in the gym
        if (!inside) {
          _checkAndStartActiveExercise();
        }
      } catch (e) {
        debugPrint('Error while checking location in background: $e');
        
        // Try with last known position as fallback
        try {
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            final Distance distance = Distance();
            final double dist = distance(
              LatLng(lastPos.latitude, lastPos.longitude),
              gymLoc,
            );
            final bool inside = dist <= gymRadiusMeters;
            
            if (mounted) {
              setState(() {
                inGym = inside;
              });
            } else {
              inGym = inside;
            }
          }
        } catch (fallbackError) {
          debugPrint('Error getting last known position in background: $fallbackError');
        }
      }
    });
  }

  Future<void> _setupApp() async {
    await _requestPermissions();
    await NotificationService().init();
    NotificationService().onAction = _onNotificationAction;
    await _startBackgroundMode();
    await _loadGymLocation();
    await _checkIfInGym();
    await _loadBackendStatus();
    if (inGym) {
      _startGymFlowIfNeeded();
    } else {
      _checkAndStartActiveExercise();
    }
    _startLocationMonitoring();
    _startActivityMonitoring();
  }
  
  void _startActivityMonitoring() async {
    final granted = await GoogleFitService.requestPermission();
    if (!granted) {
      debugPrint('Activity recognition permission not granted');
      return;
    }
    
    // Start continuous activity monitoring with callback
    GoogleFitService().startActivityMonitoring(
      callback: (activityType, isActive) {
        debugPrint('Activity detected: $activityType, isActive: $isActive');
        
        // Only start tracking if we're not in the gym and not already tracking this activity
        if (!inGym && (!running || activity != activityType) && isActive) {
          _startActivityTracking(activityType);
        }
      }
    );
  }
  
  void _startActivityTracking(String activityType) async {
    // Don't start if we're already at the gym or already tracking this activity
    if (inGym || (running && activity == activityType)) return;
    
    try {
      await BackendService.start(activityType);
      setState(() {
        activity = activityType;
        running = true;
        elapsed = Duration.zero;
      });
      _startStatusUpdates();
      _maybeUpdateNotification();
      
      // Show notification for walking activity
      if (activityType == "Walking") {
        _showCustomNotification(
          'Walking Detected',
          'GymSync is now tracking your walking activity.'
        );
      }
      
      debugPrint('Started tracking activity: $activityType at ${DateTime.now()}');
    } catch (e) {
      debugPrint('Error starting activity tracking: $e');
    }
  }

  Future<void> _loadBackendStatus() async {
    final data = await BackendService.getStatus();
    if (data != null) {
      setState(() {
        final status = data['status'];
        if (status != null) {
          activity = status['activity'] ?? activity;
          running = (status['state'] ?? 'paused') == 'active' ? true : false;
          int seconds = int.tryParse('${status['elapsed'] ?? '0'}') ?? 0;
          elapsed = Duration(seconds: seconds);
        }
        final last = data['last_session'];
        if (last != null) {
          lastActivity = last['activity'] ?? lastActivity;
          int seconds = int.tryParse('${last['elapsed'] ?? '0'}') ?? 0;
          lastElapsed = Duration(seconds: seconds);
          lastSession = '${_formatElapsed(lastElapsed)} - $lastActivity';
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
    if (await Permission.activityRecognition.isDenied) {
      await Permission.activityRecognition.request();
    }
    if (await Permission.sensors.isDenied) {
      await Permission.sensors.request();
    }
  }

  Future<void> _startBackgroundMode() async {
    final hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      await FlutterBackground.initialize(
        androidConfig: FlutterBackgroundAndroidConfig(
          notificationTitle: "GymSync Active",
          notificationText: "Tracking your workout and location in the background.",
          notificationImportance: AndroidNotificationImportance.defaultImportance,
          notificationIcon: 'ic_notification',
          enableWifiLock: true,
          showBadge: true,
          notificationChannelDescription: 'Keeps the app running in the background to track workouts and location.',
        ),
      );
    }
    
    // Try to enable background execution
    bool backgroundEnabled = false;
    try {
      backgroundEnabled = await FlutterBackground.enableBackgroundExecution();
    } catch (e) {
      debugPrint('Error enabling background execution: $e');
    }
    
    // Se não conseguir habilitar, mostra notificação
    if (!backgroundEnabled) {
      _showCustomNotification(
        'Background Execution Issue',
        'GymSync may not work properly in the background. Please check app permissions.'
      );
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _statusTimer?.cancel();
    NotificationService().cancel();
    FlutterBackground.disableBackgroundExecution();
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
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _checkIfInGym();
      if (inGym) {
        _startGymFlowIfNeeded();
      } else if (!inGym && running && activity == "Gym") {
        onStop();
        _checkAndStartActiveExercise();
      }
    });
  }

  Future<void> _startGymFlowIfNeeded() async {
    // Check if we're already running a Gym activity
    if (running && activity == "Gym") {
      return; // Already running the correct activity
    }
    
    // If we're running a different activity, stop it first
    if (running && activity != "Gym") {
      await BackendService.stop();
      setState(() {
        lastSession = '${_formatElapsed(elapsed)} - $activity';
      });
    }
    
    // Start the Gym activity
    try {
      await BackendService.start("Gym");
      setState(() {
        activity = "Gym";
        running = true;
        elapsed = Duration.zero;
      });
      _startStatusUpdates();
      _maybeUpdateNotification();
      
      // Log that the timer was started automatically
      debugPrint('Timer started automatically upon gym arrival at ${DateTime.now()}');
    } catch (e) {
      debugPrint('Error starting gym activity: $e');
      // Try again after a short delay if it fails
      Future.delayed(const Duration(seconds: 5), () {
        if (inGym && (!running || activity != "Gym")) {
          _startGymFlowIfNeeded();
        }
      });
    }
  }

  void _startStatusUpdates() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!running) return;
      setState(() {
        elapsed += const Duration(seconds: 1);
      });
      await BackendService.start(activity);
      _maybeUpdateNotification();
    });
  }

  void _stopStatusUpdates() {
    _statusTimer?.cancel();
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
      // Add timeout to prevent infinite loading
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Location request timed out');
        },
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
      
      // Notify user when they arrive at the gym (transition from outside to inside)
      if (!wasInGym && nowInGym) {
        _showGymArrivalNotification();
      }
    } catch (e) {
      debugPrint('Error while checking if in gym: $e');
      setState(() {
        inGym = false;
        locationChecked = true;
      });
      
      // Use last known position as fallback
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
          });
        }
      } catch (fallbackError) {
        debugPrint('Error getting last known position: $fallbackError');
      }
    }
  }
  
  void _showGymArrivalNotification() {
    if (!NotificationService().enabled) return;
    
    // Create a custom method in NotificationService to show gym arrival notification
    _showCustomNotification(
      'Welcome to the Gym!',
      'Your workout timer has started automatically.'
    );
  }
  
  Future<void> _showCustomNotification(String title, String body) async {
    // Use FlutterLocalNotificationsPlugin directly since we can't access the private _plugin
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
        FlutterLocalNotificationsPlugin();
    
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gym_arrival_channel',
      'Gym Arrival',
      channelDescription: 'Notifications when you arrive at the gym',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
    );
    
    await flutterLocalNotificationsPlugin.show(
      2, // Different ID from the workout notification
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  Future<void> _checkAndStartActiveExercise() async {
    if (inGym) return;
    final granted = await GoogleFitService.requestPermission();
    if (!granted) return;
    final exerciseType = await GoogleFitService().getCurrentActiveExerciseType();
    if (exerciseType != null && !running) {
      await BackendService.start(exerciseType);
      setState(() {
        activity = exerciseType;
        running = true;
        elapsed = Duration.zero;
      });
      _startStatusUpdates();
      _maybeUpdateNotification();
    }
  }

  void onPause() async {
    await BackendService.pause();
    setState(() => running = false);
    _stopStatusUpdates();
    NotificationService().cancel();
    await _loadBackendStatus();
  }

  void onResume() async {
    await BackendService.resume();
    setState(() => running = true);
    _startStatusUpdates();
    _maybeUpdateNotification();
    await _loadBackendStatus();
  }

  void onStop() async {
    await BackendService.stop();
    setState(() {
      running = false;
      lastSession = '${_formatElapsed(elapsed)} - $activity';
      elapsed = Duration.zero;
    });
    _stopStatusUpdates();
    NotificationService().cancel();
    await _loadBackendStatus();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  void _doNothing() {}

  @override
  Widget build(BuildContext context) {
    final bool controlsEnabled = running;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
              // Ao voltar das configurações, recarrega localização e estado
              await _loadGymLocation();
              await _checkIfInGym();
              setState(() {}); // força rebuild
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
                  running: running,
                  duration: elapsed,
                  activity: activity,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedButton(
                      text: running ? 'Pause' : 'Resume',
                      onPressed: controlsEnabled
                          ? (running ? onPause : onResume)
                          : _doNothing,
                      enabled: controlsEnabled,
                    ),
                    const SizedBox(width: 16),
                    AnimatedButton(
                      text: 'Stop',
                      onPressed: controlsEnabled ? onStop : _doNothing,
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
