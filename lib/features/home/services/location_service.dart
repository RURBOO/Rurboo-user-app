import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      try {
        final accuracy = await Geolocator.getLocationAccuracy();
        if (accuracy == LocationAccuracyStatus.reduced) {
          return null;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Search Error: $e');
        }
      }
    }

    try {
      debugPrint("📍 Requesting location (High Accuracy)...");
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      debugPrint("✅ Location found: ${position.latitude}, ${position.longitude}");
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("⚠️ High accuracy location failed: $e");
      try {
        debugPrint("📍 Retrying with Balanced Accuracy (Medium)...");
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 5),
          ),
        );
        debugPrint("✅ Location found (Balanced): ${position.latitude}, ${position.longitude}");
        return LatLng(position.latitude, position.longitude);
      } catch (e2) {
        debugPrint("❌ Location retrieval failed completely: $e2");
        return null;
      }
    }
  }
}
