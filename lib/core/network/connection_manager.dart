import 'package:shared_preferences/shared_preferences.dart';

/// Manages the PS5 IP configuration and connection lifecycle.
///
/// Persists the IP address via [SharedPreferences] so the user
/// doesn't need to re-enter it on every launch.
class ConnectionManager {
  static const String _ipKey = 'ps5_ip_address';

  /// Load the saved PS5 IP address, or null if none.
  static Future<String?> loadSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_ipKey);
  }

  /// Save the PS5 IP address for future sessions.
  static Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
  }

  /// Clear the saved IP address.
  static Future<void> clearIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ipKey);
  }

  /// Basic IPv4 validation.
  static bool isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    return parts.every((part) {
      final n = int.tryParse(part);
      return n != null && n >= 0 && n <= 255;
    });
  }
}
