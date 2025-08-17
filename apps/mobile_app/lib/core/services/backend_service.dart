import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BackendService {
  static const String _baseUrl = 'https://gymsync-backend-orcin.vercel.app/api/v1'; // your backend URL here
  static const String _apiKey = 'dev-key'; // default dev key, change for production

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  static Future<String?> _getDiscordId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('onboarding_discord_id');
    print('[BackendService] Fetched Discord ID: $id');
    return id;
  }

  static Future<bool> start(String activity) async {
    final discordId = await _getDiscordId();
    final url = '$_baseUrl/status';
    final body = {
      'discord_id': discordId,
      'status': {'activity': activity},
    };
    print('[BackendService] POST $url');
    print('[BackendService] Body: ${jsonEncode(body)}');
    if (discordId == null) {
      print('[BackendService] No Discord ID found.');
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      print('[BackendService] Response status: ${res.statusCode}');
      print('[BackendService] Response body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('[BackendService] ERROR on start: $e');
      return false;
    }
  }

  static Future<bool> pause() async {
    final discordId = await _getDiscordId();
    final url = '$_baseUrl/status/pause';
    final body = {'discord_id': discordId};
    print('[BackendService] POST $url');
    print('[BackendService] Body: ${jsonEncode(body)}');
    if (discordId == null) {
      print('[BackendService] No Discord ID found.');
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      print('[BackendService] Response status: ${res.statusCode}');
      print('[BackendService] Response body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('[BackendService] ERROR on pause: $e');
      return false;
    }
  }

  static Future<bool> resume() async {
    final discordId = await _getDiscordId();
    final url = '$_baseUrl/status/resume';
    final body = {'discord_id': discordId};
    print('[BackendService] POST $url');
    print('[BackendService] Body: ${jsonEncode(body)}');
    if (discordId == null) {
      print('[BackendService] No Discord ID found.');
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      print('[BackendService] Response status: ${res.statusCode}');
      print('[BackendService] Response body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('[BackendService] ERROR on resume: $e');
      return false;
    }
  }

  static Future<bool> stop() async {
    final discordId = await _getDiscordId();
    final url = '$_baseUrl/status/stop';
    final body = {'discord_id': discordId};
    print('[BackendService] POST $url');
    print('[BackendService] Body: ${jsonEncode(body)}');
    if (discordId == null) {
      print('[BackendService] No Discord ID found.');
      return false;
    }
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: _headers,
        body: jsonEncode(body),
      );
      print('[BackendService] Response status: ${res.statusCode}');
      print('[BackendService] Response body: ${res.body}');
      return res.statusCode == 200;
    } catch (e) {
      print('[BackendService] ERROR on stop: $e');
      return false;
    }
  }

  /// Optional: GET status (does not require authorization from the current backend)
  static Future<Map<String, dynamic>?> getStatus() async {
    final discordId = await _getDiscordId();
    if (discordId == null) return null;
    final url = '$_baseUrl/status/$discordId';
    try {
      final res = await http.get(Uri.parse(url));
      print('[BackendService] GET $url');
      print('[BackendService] Response status: ${res.statusCode}');
      print('[BackendService] Response body: ${res.body}');
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return null;
    } catch (e) {
      print('[BackendService] ERROR on getStatus: $e');
      return null;
    }
  }
}
