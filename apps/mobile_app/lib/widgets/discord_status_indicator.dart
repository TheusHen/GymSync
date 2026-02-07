import 'package:flutter/material.dart';
import '../core/services/discord_service.dart';

class DiscordStatusIndicator extends StatefulWidget {
  const DiscordStatusIndicator({super.key});

  @override
  State<DiscordStatusIndicator> createState() => _DiscordStatusIndicatorState();
}

class _DiscordStatusIndicatorState extends State<DiscordStatusIndicator> {
  bool _isConnected = false;
  String? _username;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final loggedIn = await DiscordService.isLoggedIn();
    final username = await DiscordService.getDiscordUsername();
    if (mounted) {
      setState(() {
        _isConnected = loggedIn;
        _username = username;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.discord, color: _isConnected ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text(
          _isConnected
              ? 'Discord RPC active${_username != null ? ' ($_username)' : ''}'
              : 'Discord RPC inactive',
        ),
      ],
    );
  }
}
