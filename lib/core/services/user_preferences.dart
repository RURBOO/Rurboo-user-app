import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {

  static const String _keyUserId = 'userId';
  static const String _keyAnnouncementEnabled = 'announcement_enabled';

  static Future<void> saveUserId(String userId) async {
    if (userId.isEmpty) {
      throw Exception('User ID cannot be empty');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserId);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }

  // Voice Announcements Preference
  static Future<void> saveAnnouncementEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAnnouncementEnabled, enabled);
  }

  static Future<bool> getAnnouncementEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true for first-time users
    return prefs.getBool(_keyAnnouncementEnabled) ?? true;
  }
}
