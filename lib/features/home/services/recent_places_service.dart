import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_places.dart';

class RecentPlacesService {
  static const _destKey = "recent_destinations";
  static const _pickupKey = "recent_pickup";

  Future<List<RecentPlace>> loadDestinations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_destKey) ?? [];
    return list.map((e) => RecentPlace.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveDestination(RecentPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await loadDestinations();

    list.removeWhere((p) => p.address == place.address);
    list.insert(0, place);

    final encoded = list.take(10).map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_destKey, encoded);
  }

  Future<void> savePickup(RecentPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pickupKey, jsonEncode(place.toJson()));
  }

  Future<RecentPlace?> loadPickup() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pickupKey);
    if (raw == null) return null;
    return RecentPlace.fromJson(jsonDecode(raw));
  }
}
