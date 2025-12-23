import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/fare_calc.dart';
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
    if (routePoints.isNotEmpty) {
      _fitCameraToRoute(routePoints);
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

    isOutstationRide = _distanceKm > 60;

    if (!isOutstationRide) {
      Map<String, dynamic>? rates;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('config')
            .doc('rates')
            .get();
        rates = doc.data();
      } catch (e) {
        debugPrint("⚠️ Using offline fare rates");
        rates = null;
      }

      _createRideOptions(rates);
    }

    loading = false;
    notifyListeners();

    if (mapController != null) {
      _fitCameraToRoute(routePoints);
    }
  }

  void _createRideOptions(Map<String, dynamic>? rates) {
    final FareResult bike = calculateFare(
      vehicleType: VehicleType.bike,
      distanceKm: _distanceKm,
      firestoreRates: rates,
    );

    final FareResult auto = calculateFare(
      vehicleType: VehicleType.auto,
      distanceKm: _distanceKm,
      firestoreRates: rates,
    );

    final FareResult car = calculateFare(
      vehicleType: VehicleType.car,
      distanceKm: _distanceKm,
      firestoreRates: rates,
    );

    rideOptions = [
      RideOption(
        name: "Bike Taxi",
        description: "Fastest • ₹${bike.totalFare.toInt()}",
        eta: "${_durationMins.toInt()} min",
        fare: bike.totalFare,
        icon: Icons.two_wheeler,
      ),
      RideOption(
        name: "Auto Rickshaw",
        description: "3 seats • ₹${auto.totalFare.toInt()}",
        eta: "${_durationMins.toInt()} min",
        fare: auto.totalFare,
        icon: Icons.electric_rickshaw,
      ),
      RideOption(
        name: "Cab",
        description: "Comfort • ₹${car.totalFare.toInt()}",
        eta: "${_durationMins.toInt()} min",
        fare: car.totalFare,
        icon: Icons.local_taxi,
      ),
    ];
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

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100,
        ),
      );
    });
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
