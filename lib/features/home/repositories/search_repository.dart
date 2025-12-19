import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_result.dart';

class SearchRepository {
  Future<List<LocationResult>> autocomplete(String query) async {
    if (query.length < 2) return [];

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$query+india&format=json&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'Accept': 'application/json', 'User-Agent': 'RuboApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((place) {
          return LocationResult(
            placeId: place['place_id'].toString(),
            address: _cleanAddress(place['display_name']),
            coordinates: LatLng(
              double.parse(place['lat']),
              double.parse(place['lon']),
            ),
          );
        }).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Search Error: $e');
      }
      return [];
    }
  }

  Future<String> reverseGeocode(LatLng point) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'RuboApp/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['display_name'] != null) {
          return _cleanAddress(data['display_name']);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Geocode Error: $e");
      }
    }
    return "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
  }

  String _cleanAddress(String raw) {
    List<String> parts = raw.split(',');

    List<String> cleanParts = parts.where((part) {
      String p = part.trim().toLowerCase();
      return !p.contains('tehsil') &&
          !p.contains('district') &&
          !p.contains('sub-district') &&
          !p.contains('state') &&
          !p.contains('india') &&
          !RegExp(r'\d{6}').hasMatch(p);
    }).toList();

    String finalAddr = cleanParts.take(3).map((s) => s.trim()).join(', ');

    return finalAddr.isEmpty ? raw : finalAddr;
  }
}
