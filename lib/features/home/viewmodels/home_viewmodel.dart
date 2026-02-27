import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/user_preferences.dart';
import '../../language/viewmodels/language_vm.dart';
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
  LocationResult? homeLocation;
  LocationResult? workLocation;
  List<LocationResult> favoriteLocations = [];

  StreamSubscription<Position>? _locationSubscription;
  DateTime _lastSyncTime = DateTime.now().subtract(const Duration(minutes: 1));

  HomeViewModel(this.repo);

  LatLng? get pickupLatLng => pickup?.coordinates;
  LatLng? get destinationLatLng => destination?.coordinates;
  String? get pickupAddress => pickup?.address;
  String? get destinationAddress => destination?.address;

  @override
  void dispose() {
    _stopLocationSync();
    super.dispose();
  }

  void _startLocationSync() async {
    _locationSubscription?.cancel();
    
    debugPrint("📍 UserApp: Starting Location Sync...");

    // Sync initial location immediately
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.balanced),
      );
      _syncLocationToFirestore(position);
    } catch (e) {
      debugPrint("⚠️ UserApp: Initial sync failed: $e");
    }
    
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.balanced,
        distanceFilter: 20, // Only sync if moved 20m
      ),
    ).listen((Position position) {
      final now = DateTime.now();
      if (now.difference(_lastSyncTime).inSeconds > 15) { // Sync every 15s max
        _lastSyncTime = now;
        _syncLocationToFirestore(position);
      }
    });
  }

  void _stopLocationSync() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  Future<void> _syncLocationToFirestore(Position position) async {
    try {
      final userId = await UserPreferences.getUserId();
      if (userId == null) return;

      debugPrint("📡 UserApp: Syncing location to Firestore for $userId");
      
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'currentLocation': GeoPoint(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("❌ UserApp: Location Sync Error: $e");
    }
  }

  void onMapCreated(GoogleMapController controller) async {
    mapController = controller;
    /*
    if (_mapStyle == null) {
      try {
        _mapStyle = await rootBundle.loadString('assets/map_styles/clean_map.json');
      } catch (e) {
        debugPrint('Map style loading error: $e');
      }
    }
    */
    // Note: setMapStyle is deprecated. Use GoogleMap.style parameter instead
    // This will be handled in the GoogleMap widget in home_screen.dart
  }

  Future<void> init(BuildContext context) async {
    if (_initialized) return;
    _initialized = true;
    
    // YIELD TO UI: Allow the frame to render before heavy lifting
    await Future.delayed(Duration.zero); // Keep for now as simple yield, but ideally use addPostFrameCallback in View

    loadingLocation = true;
    _hasLocationError = false;
    permissionDenied = false;
    notifyListeners();

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

    final latLng = await repo.getCurrentLocation();

    if (latLng == null) {
      loadingLocation = false;
      _hasLocationError = true;
      notifyListeners();
      return;
    }

    currentLocation = latLng;

    try {
      final address = await searchRepo.reverseGeocode(currentLocation!);
      // Check if reverse geocoding returned coordinates (which means it failed)
      if (address.contains(RegExp(r'^\d+\.\d+,\s*\d+\.\d+'))) {
        // If it's just coordinates, use "Current Location" instead
        pickup = LocationResult(
          address: "current_location",
          coordinates: currentLocation,
        );
      } else {
        pickup = LocationResult(address: address, coordinates: currentLocation);
      }
    } catch (_) {
      pickup = LocationResult(
        address: "current_location",
        coordinates: currentLocation,
      );
    }

    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(currentLocation!, 15),
      );
    }

    recentDestinations = await repo.loadDestinations();
    await _loadSavedLocations();

    loadingLocation = false;
    _updateMarkers(context: context.mounted ? context : null);
    
    _startLocationSync();
    
    notifyListeners();
  }

  Future<void> _loadSavedLocations() async {
    homeLocation = await UserPreferences.getHomeLocation();
    workLocation = await UserPreferences.getWorkLocation();
    favoriteLocations = await UserPreferences.getFavorites();
  }

  Future<void> saveAsHome(LocationResult loc) async {
    await UserPreferences.saveHomeLocation(loc);
    homeLocation = loc;
    notifyListeners();
  }

  Future<void> saveAsWork(LocationResult loc) async {
    await UserPreferences.saveWorkLocation(loc);
    workLocation = loc;
    notifyListeners();
  }

  Future<void> toggleFavorite(LocationResult loc) async {
    final isFav = favoriteLocations.any((e) => e.address == loc.address);
    if (isFav) {
      await UserPreferences.removeFavorite(loc.address);
      favoriteLocations.removeWhere((e) => e.address == loc.address);
    } else {
      await UserPreferences.saveFavorite(loc);
      favoriteLocations.insert(0, loc);
    }
    notifyListeners();
  }

  Future<void> setPickupLocation(LocationResult loc, {BuildContext? context}) async {
    pickup = loc;

    _updateMarkers(context: (context != null && context.mounted) ? context : null);

    if (destination != null) {
      await _drawRoute();
    } else {
      if (loc.coordinates != null && mapController != null) {
        mapController!.animateCamera(CameraUpdate.newLatLng(loc.coordinates!));
      }
    }

    notifyListeners();
  }

  Future<void> selectDestination(LocationResult loc, {BuildContext? context}) async {
    destination = loc;

    if (loc.coordinates != null) {
      await repo.saveDestination(
        RecentPlace(address: loc.address, latLng: loc.coordinates!),
      );
    }

    _updateMarkers(context: (context != null && context.mounted) ? context : null);
    await _drawRoute();
    notifyListeners();
  }
  
  // Voice Agent Helper
  Future<LocationResult?> searchByText(String text) async {
    if (text.isEmpty) return null;
    
    try {
      // 1. Check for Shortcuts
      if (text.toLowerCase() == "home" || text.toLowerCase() == "ghar") {
         if (homeLocation != null) return homeLocation;
      }
      if (text.toLowerCase() == "work" || text.toLowerCase() == "office") {
         if (workLocation != null) return workLocation;
      }
      
      // Check favorites by label or address? For now, just generic.
      for (var fav in favoriteLocations) {
        if (text.toLowerCase() == fav.address.toLowerCase()) return fav;
      }
      
      // 2. Perform Search with Location Bias
      // Pass currentLocation to prioritize nearby results
      final results = await searchRepo.autocomplete(text, focusLocation: currentLocation);
      
      if (results.isNotEmpty) {
        // Intelligence: Automatically select the FIRST result (Highest Relevance/Nearest)
        final firstMatch = results.first;
        debugPrint("🤖 Auto-Selecting Nearest: ${firstMatch.address}");
        
        final detail = await searchRepo.getPlaceDetails(firstMatch.placeId!);
        if (detail != null) {
          return LocationResult(address: detail.address, coordinates: detail.coordinates);
        }
      }
    } catch (e) {
      debugPrint("Voice Search Error: $e");
    }
    return null;
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

  void _updateMarkers({BuildContext? context}) {
    markers.clear();
    
    String pickupLabel = "Pickup";
    String dropLabel = "Drop";
    
    if (context != null) {
      try {
        final lang = Provider.of<LanguageViewModel>(context, listen: false);
        pickupLabel = lang.getText('pickup_label');
        dropLabel = lang.getText('drop_label');
      } catch (_) {}
    }

    if (pickup?.coordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup!.coordinates!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: pickupLabel, snippet: pickup!.address == 'current_location' ? pickupLabel : pickup!.address),
        ),
      );
    }

    if (destination?.coordinates != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('dest'),
          position: destination!.coordinates!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: dropLabel, snippet: destination!.address),
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
