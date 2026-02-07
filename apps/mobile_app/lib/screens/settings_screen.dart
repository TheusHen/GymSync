import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/animated_button.dart';
import '../widgets/workout_stats_widgets.dart';
import '../core/services/location_service.dart';
import '../core/services/discord_service.dart';
import '../core/services/workout_stats_service.dart';
import 'wrapped_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/notification_service.dart';
import '../main.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const MethodChannel _channel = MethodChannel('change_app_icon');
  bool _discordLoggedIn = false;
  String? _discordUsername;
  bool _persistentNotification = NotificationService().enabled;
  ThemeMode _themeMode = themeModeNotifier.value;

  @override
  void initState() {
    super.initState();
    _loadDiscordStatus();
    _loadThemeMode();
  }

  Future<void> _loadDiscordStatus() async {
    final loggedIn = await DiscordService.isLoggedIn();
    final username = await DiscordService.getDiscordUsername();
    setState(() {
      _discordLoggedIn = loggedIn;
      _discordUsername = username;
    });
  }

  void _loadThemeMode() {
    setState(() {
      _themeMode = themeModeNotifier.value;
    });
  }

  Future<void> _changeAppIcon(BuildContext context, String iconName) async {
    try {
      await _channel.invokeMethod('changeIcon', {'iconName': iconName});
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } on PlatformException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change icon: ${e.message}')),
        );
      }
    }
  }

  Future<void> _handleDiscordButton() async {
    if (_discordLoggedIn) {
      await DiscordService.logout(context);
      setState(() {
        _discordLoggedIn = false;
        _discordUsername = null;
      });
    } else {
      final user = await DiscordService.connect(context);
      if (user != null) {
        setState(() {
          _discordLoggedIn = true;
          _discordUsername = user.username;
        });
      }
    }
  }

  Future<void> _handleReconfigureGymLocation(BuildContext context) async {
    final location = await LocationService.pickGymLocation(context);
    if (location != null && mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _onThemeChanged(bool isDark) async {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      themeModeNotifier.value = _themeMode;
    });

    final prefs = await ThemePrefs.instance;
    await prefs.setThemeMode(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    final discordButtonText = _discordLoggedIn ? 'Logout' : 'Login Discord';
    final discordTileTitle = _discordLoggedIn && _discordUsername != null
        ? 'Connected as $_discordUsername'
        : 'Connect your Discord account';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Statistics Section
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'STATISTICS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          const WorkoutStatsCard(),
          const SizedBox(height: 20),
          WrappedAccessButton(
            year: DateTime.now().year,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WrappedScreen(year: DateTime.now().year),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Previous Years Wrapped'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final years = await WorkoutStatsService().getAvailableWrappedYears();
              if (years.isEmpty && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No Wrapped available yet'),
                  ),
                );
                return;
              }
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Choose a Year'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: years.length,
                        itemBuilder: (context, index) {
                          final year = years[index];
                          return ListTile(
                            title: Text('Wrapped $year'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => WrappedScreen(year: year),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          const Divider(height: 40),
          // App Settings Section
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.place),
            title: const Text('Reconfigure gym location'),
            trailing: AnimatedButton(
              text: 'Change',
              onPressed: () => _handleReconfigureGymLocation(context),
              small: true,
            ),
          ),
          const Divider(),
          if (Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Choose app icon'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Image.asset('assets/icon.png', width: 32),
                    onPressed: () => _changeAppIcon(context, 'iconDefault'),
                  ),
                  IconButton(
                    icon: Image.asset('assets/infinity_red.png', width: 32),
                    onPressed: () => _changeAppIcon(context, 'iconRed'),
                  ),
                  IconButton(
                    icon: Image.asset('assets/infinity_green.png', width: 32),
                    onPressed: () => _changeAppIcon(context, 'iconGreen'),
                  ),
                ],
              ),
            ),
          if (Platform.isIOS) const Divider(),
          SwitchListTile(
            title: const Text('Dark theme'),
            value: _themeMode == ThemeMode.dark,
            onChanged: (isDark) => _onThemeChanged(isDark),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Persistent Notification ON/OFF'),
            value: _persistentNotification,
            onChanged: (v) {
              setState(() {
                _persistentNotification = v;
                NotificationService().enable(v);
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(discordTileTitle),
            trailing: AnimatedButton(
              text: discordButtonText,
              onPressed: _handleDiscordButton,
              small: true,
            ),
          ),
        ],
      ),
    );
  }
}

class ThemePrefs {
  static const String _key = 'theme_mode';

  ThemePrefs._privateConstructor();

  static final ThemePrefs _instance = ThemePrefs._privateConstructor();

  static Future<ThemePrefs> get instance async {
    return _instance;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value == 'dark') return ThemeMode.dark;
    if (value == 'light') return ThemeMode.light;
    return ThemeMode.system;
  }
}