import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';


import '../../../core/services/user_preferences.dart';
import '../models/ride_options.dart';
import '../models/coupon_model.dart'; // Added
import '../../home/models/location_result.dart';
import '../repositories/ride_selection_repository.dart';
import '../../home/services/polyline_service.dart';
import '../services/zone_service.dart'; // Added
import '../../../core/utils/polygon_utils.dart'; // Added

class RideSelectionViewModel extends ChangeNotifier {
  final RideSelectionRepository repo;

  RideSelectionViewModel({required this.repo});

  // Coupons
  List<CouponModel> coupons = [];
  CouponModel? appliedCoupon;
  String? couponError;


  GoogleMapController? mapController;

  late LocationResult pickup;
  late LocationResult destination;

  double _distanceKm = 0.0;
  double _durationMins = 0.0;
  double _fareDistanceKm = 0.0; // Added for displacement-based pricing

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> routePoints = [];

  bool loading = true;
  RideOption? selectedRide;
  final String selectedPayment = "Cash";
  bool isOutstationRide = false;
  List<RideOption> rideOptions = [];

  /// Called once when the real OSRM route (and re-calculated fares) are ready.
  /// Register this from the screen to trigger the voice announcement at the right time.
  Function()? onRouteLoaded;

  bool _isBooking = false;
  bool get isBooking => _isBooking;
  
  bool isServiceAvailable = true; // Added for Geofencing validation

  double get distanceKm => _distanceKm;

  DateTime? scheduledTime;
  String? receiverName;
  String? receiverPhone;
  bool isBookForOthers = false;

  void setScheduledTime(DateTime? date) {
    scheduledTime = date;
    notifyListeners();
  }

  void setBookForOthers(bool value) {
    isBookForOthers = value;
    if (!value) {
      receiverName = null;
      receiverPhone = null;
    }
    notifyListeners();
  }

  void setReceiverDetails(String name, String phone) {
    receiverName = name;
    receiverPhone = phone;
    notifyListeners();
  }

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
    
    // --- GEOFENCING VALIDATION ---
    final zoneService = ZoneService();
    final activeZones = await zoneService.getActiveZones();
    bool available = false;
    
    for (var zone in activeZones) {
       if (PolygonUtils.isPointInPolygon(pickupLoc.coordinates!, zone.polygon)) {
          available = true;
          debugPrint("✅ Service is available in zone: ${zone.name}");
          break;
       }
    }
    
    isServiceAvailable = available;
    
    if (!isServiceAvailable) {
       debugPrint("❌ Service not available at pickup location.");
       loading = false;
       notifyListeners();
       
       if (mapController != null) {
         mapController?.animateCamera(CameraUpdate.newLatLngZoom(pickup.coordinates!, 14));
       }
       return; // Stop further execution
    }
    // -----------------------------

    // 🚀 Calculate Straight-Line Displacement for Fare
    final double displacement = Geolocator.distanceBetween(
      pickupLoc.coordinates!.latitude,
      pickupLoc.coordinates!.longitude,
      destLoc.coordinates!.latitude,
      destLoc.coordinates!.longitude,
    ) / 1000;
    _fareDistanceKm = displacement;
    debugPrint("📏 DISPLACEMENT (for Fare): $_fareDistanceKm km");

    // 🚀 Force One-Sided Distance (Geodesic)
    _distanceKm = distance; 
    double baseDuration = distance * 2.5; // Est. 2.5 mins/km (approx 24km/h)
    if (_distanceKm < 50) baseDuration *= 2; 
    _durationMins = baseDuration;

    // Instantly draw a straight line to not block UI rendering
    routePoints = [pickup.coordinates!, destination.coordinates!];
    debugPrint("🚀🚀🚀 Fallback to Straight Line Path for instant load");
    _setPolyline(routePoints);

    // Call OSRM asynchronously so it doesn't freeze screen transition
    _fetchActualRoute();

    isOutstationRide = _distanceKm > 200;

    // Set loading to false instantly so the map and basic UI can render.
    loading = false;
    notifyListeners();
    
    // Fit camera ASAP
    if (mapController != null) {
      _fitCameraToRoute(routePoints);
    }
    
    if (!isOutstationRide) {
      // Await fare calculation so init() completes only after fares are ready
      // This is crucial for the Voice Assistant to see a populated rideOptions list in the .then() block
      await _fetchFaresAsync();
    }
    
    // Fetch Coupons asynchronously
    fetchCoupons();
  }

  Future<void> _fetchFaresAsync() async {
    Map<String, dynamic>? rates;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('rates')
          .get(const GetOptions(source: Source.serverAndCache)); // Optimized to use cache!
      rates = doc.data();
      debugPrint("🚕 DEBUG RATES FETCHED: ${rates?.keys}");
      if(rates != null) {
        rates.forEach((k, v) => debugPrint("Rate $k: $v"));
      }
    } catch (e) {
      debugPrint("⚠️ Using offline fare rates");
      rates = null;
    }

    await _createRideOptions(rates);
    notifyListeners(); // Update the UI when fares arrive!
  }

  Future<void> _fetchActualRoute() async {
    final RouteInfo? routeInfo = await repo.getRouteDetails(
      pickup.coordinates!,
      destination.coordinates!,
    );

    if (routeInfo != null && routeInfo.points.isNotEmpty) {
      routePoints = routeInfo.points;
      _distanceKm = routeInfo.distanceKm;
      double mins = routeInfo.durationMins;
      if (_distanceKm < 50) mins *= 2;
      _durationMins = mins;
      
      debugPrint("🚀🚀🚀 Real-time Route loaded (Distance: $_distanceKm, Duration: $_durationMins). Refreshing fares...");
      
      _setPolyline(routePoints);
      
      if (mapController != null) {
        _fitCameraToRoute(routePoints);
      }
      
      // Re-calculate fares and ETAs based on the actual Google Maps data
      await _fetchFaresAsync();
      notifyListeners();
      
      // ✅ Notify the screen that the REAL route distance + fares are ready.
      // The voice announcement MUST be triggered from here, not from init().then(),
      // so it always speaks the correct (OSRM) distance and fares.
      onRouteLoaded?.call();
    }
  }

  Future<void> _createRideOptions(Map<String, dynamic>? rates) async {
    List<RideOption> newOptions = [];
    List<String> vehicleKeys = [];
    
    if (rates != null && rates.isNotEmpty) {
      vehicleKeys = rates.keys.where((k) => k != 'commission_percent').toList();
    } else {
      vehicleKeys = ['bike', 'auto', 'car', 'erickshaw', 'bigcar', 'carriertruck'];
    }

    // 🚀 Instantly calculate fares locally using the fetched/cached rules
    for (String key in vehicleKeys) {
      double secureFare = 50.0; // Fallback minimum fare
      
      if (rates != null && rates.containsKey(key)) {
        final Map<String, dynamic> vRates = rates[key] as Map<String, dynamic>;
        final double baseFare = (vRates['base_fare'] ?? 0).toDouble();
        final double perKmRate = (vRates['per_km'] ?? 0).toDouble();

        // Match the Cloud Function logic locally:
        // Base fare covers first 2km. Charges apply ONLY after 2km.
        double chargeableDistance = (_fareDistanceKm - 2.0).clamp(0.0, double.infinity);
        secureFare = baseFare + (chargeableDistance * perKmRate);
      } else {
         // Generic Fallbacks if offline or missing
         double chargeableDist = (_fareDistanceKm - 2.0).clamp(0.0, double.infinity);
         switch (key) {
          case 'bike': secureFare = 25 + (chargeableDist * 6); break;
          case 'auto': secureFare = 50 + (chargeableDist * 10); break;
          case 'car': secureFare = 80 + (chargeableDist * 18); break;
          case 'erickshaw': secureFare = 40 + (chargeableDist * 8); break;
          case 'bigcar': secureFare = 100 + (chargeableDist * 20); break;
          case 'carriertruck': secureFare = 200 + (chargeableDist * 25); break;
         }
      }

      newOptions.add(RideOption(
        id: key,
        name: _formatVehicleName(key),
        description: _calculateEta(key),
        eta: _calculateEta(key),
        fare: secureFare,
        icon: _getIconForVehicle(key),
        imageAsset: _getImageAssetForVehicle(key),
        iconColor: _getColorForVehicle(key),
        seats: _getSeatsForVehicle(key),
      ));
    }
    
    // Sort options by Price Low -> High
    newOptions.sort((a, b) => a.fare.compareTo(b.fare));

    rideOptions = newOptions;
  }
  
  // --- Helpers for Dynamic UI ---

  String _formatVehicleName(String key) {
    switch (key.toLowerCase()) {
      case 'bike': return "Bike Taxi";
      case 'auto': return "Auto Rickshaw";
      case 'erickshaw': return "E-Rickshaw";
      case 'car': return "Comfort Car";
      case 'bigcar': return "Big Car (XL)";
      case 'carriertruck': return "Carrier Truck";
      default: 
        // Capitalize: "suv" -> "Suv"
        return key[0].toUpperCase() + key.substring(1); 
    }
  }



  String _calculateEta(String key) {
    // Estimations: Bike is fastest, Truck is slowest
    double factor = 1.0;
    if (key.contains('bike')) {
      factor = 0.8;
    } else if (key.contains('auto')) {
      factor = 1.1;
    } else if (key.contains('truck')) {
      factor = 1.5;
    } else {
      factor = 1.2;
    }

    return "${(_durationMins * factor).toInt()}";
  }

  IconData _getIconForVehicle(String key) {
    final k = key.toLowerCase();
    if (k.contains('bike') || k.contains('moto')) return Icons.two_wheeler;
    if (k.contains('auto') || k.contains('rickshaw')) return Icons.local_taxi; // or generic taxi
    if (k.contains('truck') || k.contains('carrier')) return Icons.local_shipping;
    if (k.contains('big') || k.contains('suv')) return Icons.airport_shuttle;
    return Icons.directions_car;
  }

  String _getImageAssetForVehicle(String key) {
    final k = key.toLowerCase();
    if (k.contains('bike') || k.contains('moto')) return 'assets/images/vehicles/bike.png';
    if (k.contains('erickshaw')) return 'assets/images/vehicles/e_rickshaw.png';
    if (k.contains('auto') || k.contains('rickshaw')) return 'assets/images/vehicles/auto.png';
    if (k.contains('truck') || k.contains('carrier')) return 'assets/images/vehicles/truck.png';
    if (k.contains('big') || k.contains('suv')) return 'assets/images/vehicles/suv.png';
    return 'assets/images/vehicles/car.png';
  }

  Color _getColorForVehicle(String key) {
    final k = key.toLowerCase();
    if (k.contains('bike')) return const Color(0xFF2196F3);
    if (k.contains('auto')) return const Color(0xFFFFC107);
    if (k.contains('erickshaw')) return const Color(0xFF4CAF50);
    if (k.contains('truck')) return const Color(0xFF795548);
    return const Color(0xFF1E88E5);
  }

  int _getSeatsForVehicle(String key) {
    final k = key.toLowerCase();
    if (k.contains('bike')) return 1;
    if (k.contains('auto')) return 3;
    if (k.contains('erickshaw')) return 4;
    if (k.contains('big')) return 6;
    if (k.contains('truck')) return 0;
    return 4; // Default Car
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
          200,
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
    // Re-validate coupon if ride changes
    if (appliedCoupon != null) {
      applyCoupon(appliedCoupon!);
    }
    notifyListeners();
  }

  // --- Coupon Logic ---

  Future<void> fetchCoupons() async {
    try {
      final userId = await UserPreferences.getUserId();
      if (userId == null) return;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('coupons')
          .where('isUsed', isEqualTo: false)
          .where('expiryDate', isGreaterThan: Timestamp.now())
          .get();

      coupons = query.docs
          .map((d) => CouponModel.fromMap(d.id, d.data()))
          .toList();
      
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
    }
  }

  void applyCoupon(CouponModel coupon) {
    if (selectedRide == null) {
      couponError = "Select a ride first";
      notifyListeners();
      return;
    }

    if (selectedRide!.fare < 100) {
      couponError = "Minimum ride fare ₹100 required";
      appliedCoupon = null;
    } else {
      couponError = null;
      appliedCoupon = coupon;
    }
    notifyListeners();
  }

  void removeCoupon() {
    appliedCoupon = null;
    couponError = null;
    notifyListeners();
  }

  double get finalFare {
    if (selectedRide == null) return 0;
    if (appliedCoupon != null) {
      return (selectedRide!.fare - appliedCoupon!.amount).clamp(0.0, double.infinity);
    }
    return selectedRide!.fare;
  }
}
