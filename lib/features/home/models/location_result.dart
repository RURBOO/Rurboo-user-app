import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationResult {
  final String? placeId;
  final String address;
  final LatLng? coordinates;

  LocationResult({this.placeId, required this.address, this.coordinates});

  Map<String, dynamic> toJson() {
    return {
      'placeId': placeId,
      'address': address,
      'lat': coordinates?.latitude,
      'lng': coordinates?.longitude,
    };
  }

  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      placeId: json['placeId'],
      address: json['address'],
      coordinates: json['lat'] != null && json['lng'] != null
          ? LatLng(json['lat'], json['lng'])
          : null,
    );
  }
}