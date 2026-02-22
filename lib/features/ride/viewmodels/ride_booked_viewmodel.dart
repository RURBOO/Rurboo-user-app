import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../home/services/polyline_service.dart';
import '../models/ride_booking.dart';
import '../repositories/ride_booked_repository.dart';

enum RideStage { searching, arriving, inProgress, completed, cancelled }

class RideBookedViewModel extends ChangeNotifier {
  final RideBookedRepository repo;
  final PolylineService polyService = PolylineService();

  final String rideId;
  final LatLng pickupLatLng;
  final LatLng destinationLatLng;
  final String pickupAddress;
  final String destinationAddress;

  GoogleMapController? mapController;

  RideStage stage = RideStage.searching;
  RideBookingModel? rideDetails;
  String? otp;
  LatLng? driverLocation;

  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool isLoading = true;

  String eta = "~ 5 mins";
  bool kIsSosTestMode = true;

  StreamSubscription<DocumentSnapshot>? _rideStream;

  RideStage? _lastFetchedStage;
  Function(bool isDriver)? onRideCancelled;

  bool _isCameraLocked = true;
  Timer? _cameraUnlockTimer;

  bool isEndRideRequested = false;

  RideBookedViewModel({
    required this.repo,
    required this.rideId,
    required this.pickupLatLng,
    required this.destinationLatLng,
    required this.pickupAddress,
    required this.destinationAddress,
    this.rideDetails,
  });

  // Safety Fields
  String? guardianPhone;
  List<Map<String, dynamic>> trustedContacts = [];
  bool safetyModeEnabled = false;
  bool _hasAutoShared = false;
  String? userCategory;

  void setMapController(GoogleMapController c) {
    mapController = c;
  }

  void init() {
    _setStaticMarkers();
    _fetchPolyline(pickupLatLng, destinationLatLng, 'initial_route');
    _listenToRide();
    _fetchSafetySettings();
  }

  Future<void> _fetchSafetySettings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        guardianPhone = data['guardianPhone'];
        safetyModeEnabled = data['safetyModeEnabled'] ?? false;
        userCategory = data['category']; // Fetch category for safety alerts
        
        if (data['trustedContacts'] != null) {
          trustedContacts = List<Map<String, dynamic>>.from(data['trustedContacts']);
        }
        
        // Check for Auto-Share immediately if ride is already active
        if (stage == RideStage.arriving || stage == RideStage.inProgress) {
          _checkForAutoShare();
        }
      }
    } catch (e) {
      debugPrint("Error fetching safety settings: $e");
    }
  }

  void onUserPanMap() {
    _isCameraLocked = false;
    _cameraUnlockTimer?.cancel();

    _cameraUnlockTimer = Timer(const Duration(seconds: 5), () {
      _isCameraLocked = true;
    });
  }

  void _listenToRide() {
    _rideStream = FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            _handleCancellation(isDriver: false);
            return;
          }

          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];

          if (status == 'cancelled') {
            final String? cancelledBy = data['cancelledBy'];
            _handleCancellation(isDriver: cancelledBy == 'driver');
            return;
          }

          RideStage newStage = stage;

          if (status == 'accepted') {
            newStage = RideStage.arriving;
          } else if (status == 'in_progress') {
            newStage = RideStage.inProgress;
          } else if (status == 'completed') {
            newStage = RideStage.completed;
          }

          final bool stageChanged = newStage != stage;
          stage = newStage;

          // Check if driver requested to end ride early
          if (data['endRideRequested'] == true && data['endRideApproved'] != true && data['endRideRejected'] != true) {
            isEndRideRequested = true;
          } else {
            isEndRideRequested = false;
          }

          if (data['driverLocation'] != null) {
            final geo = data['driverLocation'] as GeoPoint;
            driverLocation = LatLng(geo.latitude, geo.longitude);
          }

          otp = data['otp'];

          if (data['driverName'] != null) {
            rideDetails = RideBookingModel(
              driverName: data['driverName'],
              driverPhone: data['driverPhone'] ?? "",
              carName: data['carName'] ?? 'Car',
              carNumber: data['carNumber'] ?? '',
              rating: (data['driverRating'] as num?)?.toDouble() ?? 5.0,
              fare: (data['fare'] as num).toDouble(),
              paymentMethod: data['paymentMethod'] ?? 'Cash',
            );
          }

          isLoading = false;

          _updateDriverMarker();

          if (stageChanged || _lastFetchedStage != stage || (stage == RideStage.arriving && polylines.isEmpty && driverLocation != null)) {
            _handleStageChangeRoute();
            if (newStage == RideStage.arriving || newStage == RideStage.inProgress) {
               _checkForAutoShare();
            }
          }

          notifyListeners();
        });
  }

  Future<void> callDriver() async {
    final phone = rideDetails?.driverPhone;

    if (phone == null || phone.isEmpty) {
      debugPrint("No driver phone available");
      return;
    }

    final Uri callUri = Uri(scheme: 'tel', path: phone);

    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        debugPrint("Could not launch dialer");
      }
    } catch (e) {
      debugPrint("Call Driver error: $e");
    }
  }

  void _handleCancellation({required bool isDriver}) {
    _rideStream?.cancel();
    _rideStream = null;

    stage = RideStage.cancelled;
    isLoading = false;

    notifyListeners();

    onRideCancelled?.call(isDriver);
  }

  void _setStaticMarkers() {
    markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: pickupLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: "Pickup", snippet: pickupAddress),
      ),
    );

    markers.add(
      Marker(
        markerId: const MarkerId('dest'),
        position: destinationLatLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: "Drop", snippet: destinationAddress),
      ),
    );
  }

  void _updateDriverMarker() {
    if (driverLocation == null || stage == RideStage.completed) return;

    markers.removeWhere((m) => m.markerId.value == 'driver');

    markers.add(
      Marker(
        markerId: const MarkerId('driver'),
        position: driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: "Driver"),
      ),
    );

    if (_isCameraLocked && mapController != null && driverLocation != null) {
      mapController!.animateCamera(CameraUpdate.newLatLng(driverLocation!));
    }
  }

  Future<void> _handleStageChangeRoute() async {
    _lastFetchedStage = stage;

    if (stage == RideStage.arriving && driverLocation != null) {
      await _fetchPolyline(driverLocation!, pickupLatLng, 'driver_to_pickup');
    } else if (stage == RideStage.inProgress) {
      await _fetchPolyline(pickupLatLng, destinationLatLng, 'trip_route');
    }
  }

  Future<void> _fetchPolyline(LatLng start, LatLng end, String polyId) async {
    try {
      final route = await polyService.getRouteData(start, end);

      if (route != null && route.points.isNotEmpty) {
        polylines.clear();

        polylines.add(
          Polyline(
            polylineId: PolylineId(polyId),
            points: route.points,
            color: Colors.black,
            width: 5,
          ),
        );

        if (route.durationMins < 1) {
          eta = "Arriving now";
        } else {
          eta = "${route.durationMins.toInt()} mins";
        }

        _fitCamera(route.points);

        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching polyline: $e");
    }
  }

  void _fitCamera(List<LatLng> points) {
    if (mapController == null || points.isEmpty) return;

    double minLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLat = points.first.latitude;
    double maxLng = points.first.longitude;

    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
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
            100,
          ),
        );
      } catch (_) {}
    });
  }

  Future<void> cancelRide() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint("❌ Cannot cancel ride: No Auth Session");
      return; 
    }
    
    await FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(rideId)
        .update({
          'status': 'cancelled', 
          'cancelledBy': 'user',
          'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> triggerSOS() async {
    debugPrint("🚨 SOS TRIGGERED 🚨");
    
    // 1. Alert Trusted Contacts (via SMS)
    final String message = "🆘 SOS! I feel unsafe. Track me: https://rurboo.app/track?id=$rideId";
    
    String? phone = guardianPhone;
    if (phone == null && trustedContacts.isNotEmpty) {
      phone = trustedContacts.first['phone'];
    }
    
    if (phone != null) {
        final Uri smsUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': message},
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        }
    }

    // 2. Call Police (112)
    final Uri policeUri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(policeUri)) {
      await launchUrl(policeUri);
    }
  }

  void _checkForAutoShare() {
     if (_hasAutoShared) return;
     if (safetyModeEnabled) {
       _hasAutoShared = true;
       shareRideToGuardian(auto: true);
     }
  }

  Future<void> shareRideToGuardian({bool auto = false}) async {
    final String message = "Trip Started! 🚗 Tracking Link: https://rurboo.app/track?id=$rideId";
    
    String? phone = guardianPhone;
    if (phone == null && trustedContacts.isNotEmpty) {
      phone = trustedContacts.first['phone'];
    }

    if (phone != null) {
      if (auto) {
        debugPrint("🔄 Auto-Sharing Ride with $phone");
        // Simulated auto-share notification
      } else {
         final Uri smsUri = Uri(
          scheme: 'sms',
          path: phone,
          queryParameters: {'body': message},
        );
        if (await canLaunchUrl(smsUri)) {
          await launchUrl(smsUri);
        }
      }
    }
  }

  Future<void> approveEndRide() async {
    try {
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .update({
             'endRideApproved': true,
             'endRideRequested': false,
          });
      isEndRideRequested = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error approving end ride: $e");
    }
  }

  Future<void> rejectEndRide() async {
    try {
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .update({
             'endRideRejected': true,
             'endRideRequested': false,
          });
      isEndRideRequested = false;
      notifyListeners();
    } catch (e) {
      debugPrint("Error rejecting end ride: $e");
    }
  }

  @override
  void dispose() {
    _rideStream?.cancel();
    super.dispose();
  }
}
