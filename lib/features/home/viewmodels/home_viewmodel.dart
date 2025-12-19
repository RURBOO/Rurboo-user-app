import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/services/user_preferences.dart';
import '../../ride/models/ride_booking.dart';
import '../../ride/views/ride_booked_screen.dart';
import '../../searching/views/searching_driver_screen.dart';
import '../models/recent_places.dart';
import '../repositories/home_repository.dart';
import '../models/location_result.dart';
import '../repositories/search_repository.dart';

class HomeViewModel extends ChangeNotifier {
  final HomeRepository repo;
  final SearchRepository searchRepo = SearchRepository();

  LatLng? currentLocation;
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

  LocationResult? pickup;
  LocationResult? destination;

  bool loadingLocation = false;
  bool loadingPolyline = false;
  bool permissionDenied = false;
  bool _initialized = false;

  bool _hasLocationError = false;
  bool get hasLocationError => _hasLocationError;

  List<RecentPlace> recentDestinations = [];
  String? _mapStyle;

  HomeViewModel(this.repo);

  LatLng? get pickupLatLng => pickup?.coordinates;
  LatLng? get destinationLatLng => destination?.coordinates;
  String? get pickupAddress => pickup?.address;
  String? get destinationAddress => destination?.address;

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
    if (_mapStyle == null) {
      rootBundle.loadString('assets/map_styles/clean_map.json').then((string) {
        _mapStyle = string;
        mapController?.setMapStyle(_mapStyle);
      });
    } else {
      mapController?.setMapStyle(_mapStyle);
    }
  }

  Future<void> init(BuildContext context) async {
    if (_initialized) return;
    _initialized = true;
    final userId = await UserPreferences.getUserId();

    if (userId != null) {
      final activeQuery = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('userId', isEqualTo: userId)
          .where(
            'status',
            whereIn: ['pending', 'accepted', 'arrived', 'in_progress'],
          )
          .limit(1)
          .get();

      if (activeQuery.docs.isNotEmpty && context.mounted) {
        _redirectToActiveRide(context, activeQuery.docs.first);
        return;
      }
    }

    loadingLocation = true;
    permissionDenied = false;
    _hasLocationError = false;
    notifyListeners();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      loadingLocation = false;
      permissionDenied = false;
      _hasLocationError = true;
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      loadingLocation = false;
      permissionDenied = true;
      notifyListeners();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation = LatLng(pos.latitude, pos.longitude);

      try {
        final address = await searchRepo.reverseGeocode(currentLocation!);
        pickup = LocationResult(address: address, coordinates: currentLocation);
      } catch (_) {
        pickup = LocationResult(
          address: "Unknown Location",
          coordinates: currentLocation,
        );
      }

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(currentLocation!, 15),
        );
      }
    } catch (e) {
      debugPrint("Location fetch failed: $e");

      loadingLocation = false;
      _hasLocationError = true;
      permissionDenied = false;
      notifyListeners();
      return;
    }

    recentDestinations = await repo.loadDestinations();

    loadingLocation = false;
    _updateMarkers();
    notifyListeners();
  }

  Future<void> selectDestination(LocationResult loc) async {
    destination = loc;

    if (loc.coordinates != null) {
      await repo.saveDestination(
        RecentPlace(address: loc.address, latLng: loc.coordinates!),
      );
    }

    _updateMarkers();
    await _drawRoute();
    notifyListeners();
  }

  void _redirectToActiveRide(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String?;

    final pickupGp = data['pickupCoords'];
    final destGp = data['destinationCoords'];

    if (status == null || pickupGp is! GeoPoint || destGp is! GeoPoint) {
      return;
    }

    final pickupLatLng = LatLng(pickupGp.latitude, pickupGp.longitude);
    final destLatLng = LatLng(destGp.latitude, destGp.longitude);

    final pickupAddr = data['pickupAddress'] ?? "Pickup";
    final destAddr = data['destinationAddress'] ?? "Destination";

    if (status == 'pending') {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => SearchingDriverScreen(
            rideId: doc.id,
            pickupLatLng: pickupLatLng,
            pickupAddress: pickupAddr,
            destinationLatLng: destLatLng,
            destinationAddress: destAddr,
          ),
        ),
        (route) => false,
      );
      return;
    }

    final ride = RideBookingModel(
      driverName: data['driverName'] ?? "Driver",
      driverPhone: data['driverPhone'] ?? "",
      carName: data['carName'] ?? "Car",
      carNumber: data['carNumber'] ?? "",
      rating: (data['driverRating'] ?? 4.5).toDouble(),
      fare: (data['fare'] ?? 0).toDouble(),
      paymentMethod: data['paymentMethod'] ?? "Cash",
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => RideBookedScreen(
          pickupLatLng: pickupLatLng,
          pickupAddress: pickupAddr,
          destinationLatLng: destLatLng,
          destinationAddress: destAddr,
          ride: ride,
          rideId: doc.id,
        ),
      ),
      (route) => false,
    );
  }

  void _updateMarkers() {
    markers.clear();

    if (pickup?.coordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup!.coordinates!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: "Pickup", snippet: pickup!.address),
        ),
      );
    }

    if (destination?.coordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: destination!.coordinates!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: "Drop", snippet: destination!.address),
        ),
      );
    }
  }

  Future<void> _drawRoute() async {
    if (pickup?.coordinates == null || destination?.coordinates == null) return;

    loadingPolyline = true;
    notifyListeners();

    final routeInfo = await repo.polylineService.getRouteData(
      pickup!.coordinates!,
      destination!.coordinates!,
    );

    polylines.clear();
    List<LatLng> pointsToFit = [];

    if (routeInfo != null && routeInfo.points.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          points: routeInfo.points,
          width: 5,
          color: Colors.black,
        ),
      );
      pointsToFit = routeInfo.points;
    } else {
      pointsToFit = [pickup!.coordinates!, destination!.coordinates!];
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route_fallback"),
          points: pointsToFit,
          width: 5,
          color: Colors.grey,
          patterns: [PatternItem.dash(10)],
        ),
      );
    }

    loadingPolyline = false;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 200), () {
      _fitCameraToPolyline(pointsToFit);
    });
  }

  void _fitCameraToPolyline(List<LatLng> points) {
    if (mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }

    try {
      mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          100,
        ),
      );
    } catch (e) {
      debugPrint("Camera zoom error: $e");
    }
  }

  void clearDestination() {
    destination = null;
    polylines.clear();
    _updateMarkers();

    if (pickup?.coordinates != null) {
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(pickup!.coordinates!, 15),
      );
    }

    notifyListeners();
  }
}
