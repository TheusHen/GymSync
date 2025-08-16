import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'screens/splash_screen.dart';
import 'core/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final themeValue = prefs.getString('theme_mode');
  ThemeMode initialTheme;
  if (themeValue == 'dark') {
    initialTheme = ThemeMode.dark;
  } else if (themeValue == 'light') {
    initialTheme = ThemeMode.light;
  } else {
    initialTheme = ThemeMode.system;
  }
  themeModeNotifier.value = initialTheme;

  runApp(RestartWidget(child: const MyApp()));
}

class RestartWidget extends StatefulWidget {
  final Widget child;
  const RestartWidget({super.key, required this.child});

  static void restartApp(BuildContext context) {
    final _RestartWidgetState? state = context.findAncestorStateOfType<_RestartWidgetState>();
    state?.restartApp();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<void> handleBackgroundExecution(BuildContext context) async {
    await FlutterBackground.initialize(
      androidConfig: const FlutterBackgroundAndroidConfig(
        notificationTitle: "GymSync Running",
        notificationText: "Your workout is being monitored in the background.",
        enableWifiLock: true,
      ),
    );
    await FlutterBackground.enableBackgroundExecution();
    RestartWidget.restartApp(context);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'GymSync App',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          navigatorKey: navigatorKey,
          home: SplashScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}