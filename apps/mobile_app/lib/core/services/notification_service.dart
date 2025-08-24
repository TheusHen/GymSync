import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

typedef NotificationActionCallback = void Function(String action);

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  NotificationActionCallback? onAction;

  bool _enabled = true;

  void _ensureBindingInitialized() {
    if (WidgetsBinding.instance == null) {
      WidgetsFlutterBinding.ensureInitialized();
    }
  }

  Future<void> init({GlobalKey<NavigatorState>? navigatorKey}) async {
    _ensureBindingInitialized();
    const AndroidInitializationSettings android = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (response.actionId != null && response.actionId!.isNotEmpty) {
          if (onAction != null) onAction!(response.actionId!);
        } else if (navigatorKey != null) {
          navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
        }
      },
    );
  }

  void enable(bool value) {
    _enabled = value;
    if (!value) cancel();
  }

  bool get enabled => _enabled;

  Future<void> show({
    required String elapsed,
    required String activity,
  }) async {
    if (!_enabled) return;
    _ensureBindingInitialized();
    final android = AndroidNotificationDetails(
      'persistent_gym_channel',
      'Persistent Gym',
      channelDescription: 'Shows ongoing workout',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      icon: 'ic_notification',
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'pause',
          'Pause',
          icon: DrawableResourceAndroidBitmap('ic_pause'),
        ),
        AndroidNotificationAction(
          'stop',
          'Stop',
          icon: DrawableResourceAndroidBitmap('ic_stop'),
        ),
      ],
      category: AndroidNotificationCategory.service,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: false,
    );
    await _plugin.show(
      1,
      elapsed,
      activity,
      NotificationDetails(android: android),
      payload: '',
    );
  }

  Future<void> cancel() async {
    _ensureBindingInitialized();
    await _plugin.cancel(1);
  }
}
