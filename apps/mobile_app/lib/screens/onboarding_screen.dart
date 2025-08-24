import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/animated_button.dart';
import '../core/services/discord_service.dart';
import '../core/services/location_service.dart';
import '../core/services/health_service.dart';
import 'home_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool discordConnected = false;
  bool locationSet = false;
  bool healthGranted = false;
  String? discordUsername;
  bool isSamsung = false;
  bool healthChecked = false;
  bool requestingHealth = false;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _initOnboarding();
  }

  Future<void> _initOnboarding() async {
    await _loadSavedProgress();
    await _detectDeviceAndCheckHealthPermissions();
    if (_allCompleted()) {
      _goToHome();
      return;
    }
    setState(() {
      loading = false;
    });
  }

  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    discordConnected = prefs.getBool('onboarding_discord') ?? false;
    discordUsername = prefs.getString('onboarding_discord_username');
    locationSet = prefs.getBool('onboarding_gym') ?? false;
    healthGranted = prefs.getBool('onboarding_health') ?? false;
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_discord', discordConnected);
    if (discordUsername != null) await prefs.setString('onboarding_discord_username', discordUsername!);
    await prefs.setBool('onboarding_gym', locationSet);
    await prefs.setBool('onboarding_health', healthGranted);
  }

  bool _allCompleted() {
    return discordConnected && locationSet && healthGranted;
  }

  void _goToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  Future<void> _detectDeviceAndCheckHealthPermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      isSamsung = androidInfo.manufacturer.toLowerCase().contains('samsung');
    } else {
      isSamsung = false;
    }
    await _refreshHealthStatus();
  }

  Future<void> _refreshHealthStatus() async {
    final alreadyGranted = await _checkHealthPermissions();
    setState(() {
      healthChecked = true;
      healthGranted = alreadyGranted;
    });
    await _saveProgress();
  }

  Future<bool> _checkHealthPermissions() async {
    final activity = await Permission.activityRecognition.status;
    final sensors = await Permission.sensors.status;
    final location = await Permission.locationWhenInUse.status;
    bool notificationGranted = true;
    if (Platform.isAndroid) {
      notificationGranted = await Permission.notification.isGranted;
    }
    if (!activity.isGranted || !sensors.isGranted || !location.isGranted || !notificationGranted) {
      return false;
    }
    return await HealthService().checkAllPermissionsGranted();
  }

  Future<void> connectDiscord() async {
    final user = await DiscordService.connect(context);
    if (user != null) {
      setState(() {
        discordConnected = true;
        discordUsername = user.username;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('onboarding_discord_id', user.id);
      await _saveProgress();
      if (_allCompleted()) _goToHome();
    }
  }

  Future<void> selectGym() async {
    final location = await LocationService.pickGymLocation(context);
    if (location != null) {
      setState(() => locationSet = true);
      await _saveProgress();
      if (_allCompleted()) _goToHome();
    }
  }

  Future<void> enableHealth() async {
    if (requestingHealth) return;
    setState(() => requestingHealth = true);
    final granted = await HealthService.requestPermission(
      preferSamsung: isSamsung,
    );
    await _refreshHealthStatus();
    setState(() => requestingHealth = false);
    await _saveProgress();
    if (!healthGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Health access permission is mandatory. Please grant permissions in settings.')),
      );
    }
    if (_allCompleted()) _goToHome();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || !healthChecked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome To GymSync!',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              _StepTile(
                title: 'Connect your Discord account.',
                status: discordConnected,
                onPressed: connectDiscord,
                buttonText: 'Connect Discord',
              ),
              const SizedBox(height: 16),
              _StepTile(
                title: 'Select your gym location.',
                status: locationSet,
                onPressed: selectGym,
                buttonText: 'Select Gym Location',
              ),
              const SizedBox(height: 16),
              _StepTile(
                title: isSamsung
                    ? 'Allow access to Samsung Health.'
                    : 'Allow access to Google Fit.',
                status: healthGranted,
                onPressed: enableHealth,
                buttonText: isSamsung ? 'Enable Samsung Health' : 'Enable Google Fit',
                loading: requestingHealth,
              ),
              const Spacer(),
              AnimatedButton(
                enabled: _allCompleted(),
                text: 'Start',
                onPressed: _goToHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String title;
  final bool status;
  final VoidCallback onPressed;
  final String buttonText;
  final bool loading;

  const _StepTile({
    required this.title,
    required this.status,
    required this.onPressed,
    required this.buttonText,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: status
          ? const Icon(Icons.check_circle, color: Colors.green)
          : const Icon(Icons.radio_button_unchecked),
      title: Text(title),
      trailing: loading
          ? const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : AnimatedButton(
        enabled: !status,
        text: buttonText,
        onPressed: onPressed,
        small: true,
      ),
    );
  }
}