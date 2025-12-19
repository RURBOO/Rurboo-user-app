import 'package:google_maps_flutter/google_maps_flutter.dart';

class DriverModel {
  final String name;
  final String driverPhone;
  final String carName;
  final String carNumber;
  final double rating;
  final LatLng driverLocation;

  DriverModel({
    required this.name,
    required this.driverPhone,
    required this.carName,
    required this.carNumber,
    required this.rating,
    required this.driverLocation,
  });
}
