import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/services/user_preferences.dart';
import '../../language/views/language_selection_screen.dart';
import '../../navigation/views/main_navigator.dart';
import '../../ride/views/ride_summary_screen.dart';
import '../../searching/views/searching_driver_screen.dart';
import '../../ride/views/ride_booked_screen.dart';
import '../../ride/models/ride_booking.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> fade;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    fade = Tween(begin: 0.0, end: 1.0).animate(controller);
    controller.forward();

    _checkInternetAndStart();
  }

  Future<void> _checkInternetAndStart() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      if (!mounted) return;
      _showNoInternetDialog();
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final userId = await UserPreferences.getUserId();
    if (userId == null) {
      _navigateTo(const LanguageSelectionScreen());
      return;
    }

    try {
      final query = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('userId', isEqualTo: userId)
          .where(
            'status',
            whereIn: [
              'pending',
              'accepted',
              'arrived',
              'in_progress',
              'completed',
            ],
          )
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        final rideId = doc.id;

        final status = data['status'] as String?;

        if (status == null) {
          _navigateTo(const MainNavigator());
          return;
        }

        if (status == 'completed') {
          final double fare = (data['fare'] as num?)?.toDouble() ?? 0.0;
          final String driverName = data['driverName'] ?? "Driver";

          _navigateTo(
            RideSummaryScreen(
              rideId: rideId,
              fare: fare,
              driverName: driverName,
            ),
          );
          return;
        }

        final pickupGp = data['pickupCoords'];
        final destGp = data['destinationCoords'];

        if (pickupGp is! GeoPoint || destGp is! GeoPoint) {
          _navigateTo(const MainNavigator());
          return;
        }

        final pickupLatLng = LatLng(pickupGp.latitude, pickupGp.longitude);
        final destLatLng = LatLng(destGp.latitude, destGp.longitude);

        final pickupAddr = data['pickupAddress'] ?? "Unknown Location";
        final destAddr = data['destinationAddress'] ?? "Unknown Destination";

        if (status == 'pending') {
          _navigateTo(
            SearchingDriverScreen(
              rideId: rideId,
              pickupLatLng: pickupLatLng,
              pickupAddress: pickupAddr,
              destinationLatLng: destLatLng,
              destinationAddress: destAddr,
            ),
          );
        } else {
          final rideModel = RideBookingModel(
            driverName: data['driverName'] ?? "Unknown Driver",
            driverPhone: data['driverPhone'] ?? "",
            carName: data['carName'] ?? "Taxi",
            carNumber: data['carNumber'] ?? "",
            rating: (data['driverRating'] ?? 4.5).toDouble(),
            fare: (data['fare'] ?? 0).toDouble(),
            paymentMethod: data['paymentMethod'] ?? "Cash",
          );

          _navigateTo(
            RideBookedScreen(
              pickupLatLng: pickupLatLng,
              pickupAddress: pickupAddr,
              destinationLatLng: destLatLng,
              destinationAddress: destAddr,
              ride: rideModel,
              rideId: rideId,
            ),
          );
        }
      } else {
        _navigateTo(const MainNavigator());
      }
    } catch (e) {
      debugPrint("Splash restore error: $e");
      _navigateTo(const MainNavigator());
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Connection Error"),
        content: const Text("Please check your internet connection."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkInternetAndStart();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => screen),
      (route) => false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: fade,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "RURBOO",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}
