import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';


import '../../../core/services/user_preferences.dart';
import '../models/ride_options.dart';
import '../models/coupon_model.dart'; // Added
import '../../home/models/location_result.dart';
import '../repositories/ride_selection_repository.dart';
import '../../home/services/polyline_service.dart';

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

    final RouteInfo? routeInfo = await repo.getRouteDetails(
      pickup.coordinates!,
      destination.coordinates!,
    );

    // 🚀 Force One-Sided Distance (Geodesic)
    // OSRM was returning ~2x distance (likely round trip), causing double fare.
    _distanceKm = distance; 
    _durationMins = distance * 2.5; // Est. 2.5 mins/km (approx 24km/h)

    if (routeInfo != null) {
      routePoints = routeInfo.points;
      debugPrint("🚀🚀🚀 Using OSRM Path (Visual Only). Ignored OSRM Dist: ${routeInfo.distanceKm} km");
    } else {
      routePoints = [pickup.coordinates!, destination.coordinates!];
      debugPrint("🚀🚀🚀 Fallback to Straight Line Path");
    }

    _setPolyline(routePoints);

    isOutstationRide = _distanceKm > 100;

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

      await _createRideOptions(rates);
    }
    
    // Fetch Coupons
    fetchCoupons();

    loading = false;
    notifyListeners();

    if (mapController != null) {
      _fitCameraToRoute(routePoints);
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

    // Call Cloud Function to get secure fares
    final HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'asia-south1').httpsCallable('provideFare');

    try {
      // Fetch all fares in parallel for better performance
      final List<Future<void>> fareRequests = vehicleKeys.map((key) async {
        try {
          final result = await callable.call({
            'vehicleKey': key,
            'distanceKm': _distanceKm,
          });

          final double secureFare = (result.data['fare'] as num).toDouble();
          
          newOptions.add(RideOption(
            id: key,
            name: _formatVehicleName(key),
            description: _calculateEta(key),
            eta: _calculateEta(key),
            fare: secureFare,
            icon: _getIconForVehicle(key),
            iconColor: _getColorForVehicle(key),
            seats: _getSeatsForVehicle(key),
          ));
        } catch (e) {
          debugPrint("❌ Failed to fetch secure fare for $key: $e");
          // Fallback to local calculation if needed, but in production this should be a hard requirement
          // For now, if one fails, we just don't add it or log error.
        }
      }).toList();

      await Future.wait(fareRequests);
    } catch (e) {
      debugPrint("❌ Global fare calculation error: $e");
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

    return "${(_durationMins * factor).toInt()} min";
  }

  IconData _getIconForVehicle(String key) {
    final k = key.toLowerCase();
    if (k.contains('bike') || k.contains('moto')) return Icons.two_wheeler;
    if (k.contains('auto') || k.contains('rickshaw')) return Icons.local_taxi; // or generic taxi
    if (k.contains('truck') || k.contains('carrier')) return Icons.local_shipping;
    if (k.contains('big') || k.contains('suv')) return Icons.airport_shuttle;
    return Icons.directions_car;
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
