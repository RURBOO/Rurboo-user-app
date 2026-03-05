import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_result.dart';

class SearchRepository {
  // Headers required for Android-restricted API Keys when making direct HTTP calls
  Map<String, String> get _headers {
    // Release SHA-1: 6A:0F:93:82:14:47:6B:9B:90:2A:33:E7:7B:00:8A:12:38:8C:D7:28 (From rurboo-release-key.jks)
    // Debug SHA-1: Will be extracted from ~/.android/debug.keystore
    
    // Get debug SHA-1 (default Android debug keystore)
    // Run: keytool -list -v -keystore ~/.android/debug.keystore -storepass android -keypass android | grep SHA1
    
    if (kDebugMode) {
      // Using debug keystore SHA-1: D2:EF:14:F3:EB:8E:65:90:29:22:26:1E:90:09:7F:18:2F:D6:A6:E0
      // NOTE: This is specific to this developer machine's debug keystore
      // If another developer runs this, they need to add THEIR debug SHA-1 to Google Cloud Console
      return {
        'Content-Type': 'application/json',
        'X-Android-Package': 'com.rurboo.app',
        'X-Android-Cert': 'D2EF14F3EB8E65902922261E90097F182FD6A6E0',
      };
    }
    
    return {
        'Content-Type': 'application/json',
        'X-Android-Package': 'com.rurboo.app',
        'X-Android-Cert': '6A0F938214476B9B902A33E77B008A12388CD728',
      };
  }

  Future<List<LocationResult>> autocomplete(String query, {LatLng? focusLocation, String language = 'en'}) async {
    if (query.length < 2) return [];

    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      if (apiKey == null) {
        debugPrint("❌ Missing GOOGLE_MAPS_API_KEY in .env");
        return [];
      }

      String urlString = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$query&key=$apiKey&components=country:in&language=$language';
      
      // Add Location Bias (radius 50km)
      if (focusLocation != null) {
         urlString += '&location=${focusLocation.latitude},${focusLocation.longitude}&radius=50000';
      }

      final url = Uri.parse(urlString);

      debugPrint('🔍 Autocomplete Request: $url');
      final response = await http.get(url, headers: _headers);
      debugPrint('🔍 Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          return (data['predictions'] as List).map((p) {
            return LocationResult(
              placeId: p['place_id'],
              address: p['description'],
              coordinates: null, // Coordinates fetched on selection
            );
          }).toList();
        } else {
          debugPrint('❌ Autocomplete API Error: ${data['status']} - ${data['error_message']}');
        }
      }
      return [];
    } catch (e) {
      debugPrint('❌ Search Exception: $e');
      return [];
    }
  }

  Future<LocationResult?> getPlaceDetails(String placeId, {String language = 'en'}) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&language=$language',
      );

      final response = await http.get(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          return LocationResult(
            placeId: placeId,
            address: result['formatted_address'] ?? result['name'],
            coordinates: LatLng(location['lat'], location['lng']),
          );
        } else {
             debugPrint('❌ Details API Error: ${data['status']} - ${data['error_message']}');
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Details Exception: $e');
      return null;
    }
  }

  Future<String> reverseGeocode(LatLng point, {String language = 'en'}) async {
    try {
      final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${point.latitude},${point.longitude}&key=$apiKey&language=$language',
      );

      final response = await http.get(url, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && (data['results'] as List).isNotEmpty) {
          return data['results'][0]['formatted_address'];
        } else {
             debugPrint('❌ Geocode API Error: ${data['status']} - ${data['error_message']}');
        }
      }
    } catch (e) {
      debugPrint("❌ Geocode Exception: $e");
    }
    return "${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}";
  }


}
