import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  static const String _baseUrl = 'https://gymsync-backend-orcin.vercel.app/api/v1';
  static const String _apiKey = 'dev-key';

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  static Future<String?> _getDiscordId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('onboarding_discord_id');
    return id;
  }

  /// Start a new activity session. Only call this ONCE when starting.
  static Future<bool> start(String activity) async {
    final discordId = await _getDiscordId();
    if (discordId == null) {
      debugPrint('[BackendService] No Discord ID found.');
      return false;
    }
    final url = '$_baseUrl/status';
    final body = {
      'discord_id': discordId,
      'status': {'activity': activity},
    };
    debugPrint('[BackendService] POST $url');
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint('[BackendService] start -> ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] ERROR on start: $e');
      return false;
    }
  }

  /// Send a heartbeat to keep the session alive without resetting the timer.
  static Future<Map<String, dynamic>?> heartbeat() async {
    final discordId = await _getDiscordId();
    if (discordId == null) return null;
    final url = '$_baseUrl/status/heartbeat';
    final body = {'discord_id': discordId};
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      debugPrint('[BackendService] ERROR on heartbeat: $e');
      return null;
    }
  }

  static Future<bool> pause() async {
    final discordId = await _getDiscordId();
    if (discordId == null) {
      debugPrint('[BackendService] No Discord ID found.');
      return false;
    }
    final url = '$_baseUrl/status/pause';
    final body = {'discord_id': discordId};
    debugPrint('[BackendService] POST $url');
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint('[BackendService] pause -> ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] ERROR on pause: $e');
      return false;
    }
  }

  static Future<bool> resume() async {
    final discordId = await _getDiscordId();
    if (discordId == null) {
      debugPrint('[BackendService] No Discord ID found.');
      return false;
    }
    final url = '$_baseUrl/status/resume';
    final body = {'discord_id': discordId};
    debugPrint('[BackendService] POST $url');
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint('[BackendService] resume -> ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] ERROR on resume: $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    final discordId = await _getDiscordId();
    if (discordId == null) {
      debugPrint('[BackendService] No Discord ID found.');
      return false;
    }
    final url = '$_baseUrl/status/stop';
    final body = {'discord_id': discordId};
    debugPrint('[BackendService] POST $url');
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      debugPrint('[BackendService] stop -> ${res.statusCode}');
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[BackendService] ERROR on stop: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getStatus() async {
    final discordId = await _getDiscordId();
    if (discordId == null) return null;
    final url = '$_baseUrl/status/$discordId';
    try {
      final res = await http.get(Uri.parse(url));
      debugPrint('[BackendService] GET status -> ${res.statusCode}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      debugPrint('[BackendService] ERROR on getStatus: $e');
      return null;
    }
  }
}
