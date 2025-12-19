import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/ride_options.dart';
import '../../home/models/location_result.dart';
import '../repositories/ride_selection_repository.dart';
import '../../home/services/polyline_service.dart';

class RideSelectionViewModel extends ChangeNotifier {
  final RideSelectionRepository repo;

  RideSelectionViewModel({required this.repo});

  GoogleMapController? mapController;

  late LocationResult pickup;
  late LocationResult destination;

  double _distanceKm = 0.0;
  double _durationMins = 0.0;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> routePoints = [];

  bool loading = true;
  RideOption? selectedRide;
  final String selectedPayment = "Cash";
  bool isOutstationRide = false;
  List<RideOption> rideOptions = [];

  bool _isBooking = false;
  bool get isBooking => _isBooking;

  void setMapController(GoogleMapController c) {
    mapController = c;

    if (pickup.coordinates != null && destination.coordinates != null) {
      if (routePoints.isNotEmpty) {
        _fitCameraToRoute(routePoints);
      } else {
        _fitCameraToRoute([pickup.coordinates!, destination.coordinates!]);
      }
    }
  }

  Future<void> init({
    required LocationResult pickupLoc,
    required LocationResult destLoc,
    required double distance,
  }) async {
    loading = true;
    notifyListeners();

    pickup = pickupLoc;
    destination = destLoc;

    _setMarkers();

    final RouteInfo? routeInfo = await repo.getRouteDetails(
      pickup.coordinates!,
      destination.coordinates!,
    );

    if (routeInfo != null) {
      routePoints = routeInfo.points;
      _distanceKm = routeInfo.distanceKm;
      _durationMins = routeInfo.durationMins;
    } else {
      routePoints = [pickup.coordinates!, destination.coordinates!];
      _distanceKm = distance;
      _durationMins = distance * 3;
    }

    _setPolyline(routePoints);

    if (_distanceKm > 60) {
      isOutstationRide = true;
    } else {
      isOutstationRide = false;
      final rates = await repo.fetchRideRates();
      _createProfessionalRideOptions(rates);
    }

    loading = false;
    notifyListeners();

    if (mapController != null) {
      _fitCameraToRoute(routePoints);
    }
  }

  Future<bool> bookRide(Future<void> Function() action) async {
    if (_isBooking) return false;

    _isBooking = true;
    notifyListeners();

    try {
      await action();

      _isBooking = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isBooking = false;
      notifyListeners();
      return false;
    }
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      try {
        mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(minLat, minLng),
              northeast: LatLng(maxLat, maxLng),
            ),
            100.0,
          ),
        );
      } catch (e) {
        debugPrint("Camera Zoom Error: $e");
      }
    });
  }

  void _createProfessionalRideOptions(Map<String, dynamic> rates) {
    final now = TimeOfDay.now();
    final double currentHour = now.hour + (now.minute / 60.0);

    final bool isNight = currentHour < 6.0 || currentHour >= 22.0;

    if (kDebugMode) {
      print("Logic Check: Hour=$currentHour | Is Night? $isNight");
    }

    double getRate(String vehicleType, String key, double fallback) {
      try {
        if (rates[vehicleType] != null && rates[vehicleType] is Map) {
          final val = rates[vehicleType][key];
          if (val is num) return val.toDouble();
          if (val is String) return double.tryParse(val) ?? fallback;
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error parsing rate for $vehicleType/$key");
        }
      }
      return fallback;
    }

    double carBase, carPerKm;
    double autoBase, autoPerKm;
    double bikeBase, bikePerKm;

    if (isNight) {
      carBase = getRate('car', 'night_base_fare', 80.0);
      carPerKm = getRate('car', 'night_per_km', 16.0);

      autoBase = getRate('auto', 'night_base_fare', 60.0);
      autoPerKm = getRate('auto', 'night_per_km', 12.0);

      bikeBase = getRate('bike', 'night_base_fare', 40.0);
      bikePerKm = getRate('bike', 'night_per_km', 8.0);
    } else {
      carBase = getRate('car', 'base_fare', 100.0);
      carPerKm = getRate('car', 'per_km', 15.0);

      autoBase = getRate('auto', 'base_fare', 50.0);
      autoPerKm = getRate('auto', 'per_km', 10.0);

      bikeBase = getRate('bike', 'base_fare', 30.0);
      bikePerKm = getRate('bike', 'per_km', 6.0);
    }

    rideOptions = [
      RideOption(
        name: "Bike Taxi",
        description: isNight ? "Night Fare" : "1 person",
        eta: "${_durationMins.toInt()} min",
        fare: (bikeBase + (_distanceKm * bikePerKm)).roundToDouble(),
        icon: Icons.two_wheeler,
      ),
      RideOption(
        name: "Auto Rickshaw",
        description: isNight ? "Night Fare" : "3 people",
        eta: "${_durationMins.toInt()} min",
        fare: (autoBase + (_distanceKm * autoPerKm)).roundToDouble(),
        icon: Icons.electric_rickshaw,
      ),
      RideOption(
        name: "Cab",
        description: isNight ? "Night Fare" : "4 people",
        eta: "${_durationMins.toInt()} min",
        fare: (carBase + (_distanceKm * carPerKm)).roundToDouble(),
        icon: Icons.local_taxi,
      ),
    ];
  }

  void _setMarkers() {
    markers = {
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickup.coordinates!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: destination.coordinates!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  void _setPolyline(List<LatLng> points) {
    polylines = {
      Polyline(
        polylineId: const PolylineId("route_border"),
        points: points,
        width: 6,
        color: Colors.black,
      ),
      Polyline(
        polylineId: const PolylineId("route_inner"),
        points: points,
        width: 4,
        color: Colors.blueAccent,
      ),
    };
  }

  void selectRide(RideOption ride) {
    selectedRide = ride;
    notifyListeners();
  }
}
