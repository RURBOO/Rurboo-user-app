import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationService {
  Future<LatLng?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      final accuracy = await Geolocator.getLocationAccuracy();
      if (accuracy == LocationAccuracyStatus.reduced) {
        return null;
      }
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return null;
    }
  }
}
