import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/home/models/location_result.dart';

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

  // Home Location
  static const String _keyHomeLocation = 'home_location';

  static Future<void> saveHomeLocation(LocationResult location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeLocation, jsonEncode(location.toJson()));
  }

  static Future<LocationResult?> getHomeLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyHomeLocation);
    if (jsonString != null) {
      try {
        return LocationResult.fromJson(jsonDecode(jsonString));
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}
