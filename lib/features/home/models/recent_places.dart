import 'package:google_maps_flutter/google_maps_flutter.dart';

class RecentPlace {
  final String address;
  final LatLng latLng;

  RecentPlace({required this.address, required this.latLng});

  Map<String, dynamic> toJson() => {
    "address": address,
    "lat": latLng.latitude,
    "lng": latLng.longitude,
  };

  factory RecentPlace.fromJson(Map<String, dynamic> json) {
    return RecentPlace(
      address: json["address"],
      latLng: LatLng(
        (json["lat"] as num).toDouble(),
        (json["lng"] as num).toDouble(),
      ),
    );
  }
}
