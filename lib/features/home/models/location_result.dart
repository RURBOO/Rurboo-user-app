import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationResult {
  final String? placeId;
  final String address;
  final LatLng? coordinates;

  LocationResult({this.placeId, required this.address, this.coordinates});
}