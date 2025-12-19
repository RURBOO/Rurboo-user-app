import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/driver_model.dart';
import '../../navigation/views/main_navigator.dart';

class SearchingDriverViewModel extends ChangeNotifier {
  final String rideId;
  final LatLng pickupLatLng;

  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Timer? _timeoutTimer;

  VoidCallback? onTimeout;
  Function(DriverModel driver)? onDriverFound;

  SearchingDriverViewModel({required this.rideId, required this.pickupLatLng});

  void startListeningForDriver() {
    _timeoutTimer?.cancel();
    _rideSubscription?.cancel();

    _timeoutTimer = Timer(const Duration(minutes: 3), _handleTimeout);

    _rideSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) return;

          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'];
          final driverId = data['driverId'];

          if (status == 'accepted' && driverId != null) {
            _timeoutTimer?.cancel();

            LatLng driverLoc = const LatLng(28.625, 77.112);
            if (data['driverLocation'] != null) {
              final geo = data['driverLocation'] as GeoPoint;
              driverLoc = LatLng(geo.latitude, geo.longitude);
            }

            final driver = DriverModel(
              name: data['driverName'] ?? "Driver",
              driverPhone: data['driverPhone'] ?? "",
              carName: data['carName'] ?? "Taxi",
              carNumber: data['carNumber'] ?? "",
              rating: (data['driverRating'] ?? 4.5).toDouble(),
              driverLocation: driverLoc,
            );

            onDriverFound?.call(driver);
            stopListening();
          }
        });
  }

  void _handleTimeout() async {
    stopListening();

    try {
      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .update({'status': 'cancelled'});
    } catch (e) {
      debugPrint("Timeout cancel failed: $e");
    }

    onTimeout?.call();
  }

  Future<void> cancelRide(BuildContext context) async {
    try {
      _timeoutTimer?.cancel();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .update({'status': 'cancelled'});

      stopListening();

      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      debugPrint("Error cancelling ride: $e");
    }
  }

  Future<void> checkForUpdates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideId)
          .get();

      if (!doc.exists || doc.data() == null) return;

      final data = doc.data()!;
      final status = data['status'];
      final driverId = data['driverId'];

      if (status == 'accepted' && driverId != null) {
        LatLng driverLoc = const LatLng(28.625, 77.112);
        if (data['driverLocation'] != null) {
          final geo = data['driverLocation'] as GeoPoint;
          driverLoc = LatLng(geo.latitude, geo.longitude);
        }

        final driver = DriverModel(
          name: data['driverName'] ?? "Driver",
          driverPhone: data['driverPhone'] ?? "",
          carName: data['carName'] ?? "Taxi",
          carNumber: data['carNumber'] ?? "",
          rating: (data['driverRating'] ?? 4.5).toDouble(),
          driverLocation: driverLoc,
        );

        onDriverFound?.call(driver);
        stopListening();
      }
    } catch (e) {
      debugPrint("checkForUpdates error: $e");
    }
  }

  void stopListening() {
    _rideSubscription?.cancel();
    _rideSubscription = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
