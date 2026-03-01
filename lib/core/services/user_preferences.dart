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

  // Work Location
  static const String _keyWorkLocation = 'work_location';

  static Future<void> saveWorkLocation(LocationResult location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyWorkLocation, jsonEncode(location.toJson()));
  }

  static Future<LocationResult?> getWorkLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_keyWorkLocation);
    if (jsonString != null) {
      try {
        return LocationResult.fromJson(jsonDecode(jsonString));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  // Favorites
  static const String _keyFavorites = 'favorite_locations';

  static Future<void> saveFavorite(LocationResult location) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    
    // Avoid duplicates by address
    favorites.removeWhere((item) => item.address == location.address);
    favorites.insert(0, location);
    
    final List<String> encoded = favorites.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyFavorites, encoded);
  }

  static Future<List<LocationResult>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? list = prefs.getStringList(_keyFavorites);
    if (list != null) {
      return list.map((e) => LocationResult.fromJson(jsonDecode(e))).toList();
    }
    return [];
  }

  static Future<void> removeFavorite(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.removeWhere((item) => item.address == address);
    final List<String> encoded = favorites.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_keyFavorites, encoded);
  }

  // Onboarding
  static const String _keyFirstTime = 'firstTimeOnboarding';

  static Future<bool> isFirstTime() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyFirstTime) ?? true;
  }

  static Future<void> setFirstTime(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstTime, value);
  }
}
