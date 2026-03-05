import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/services/user_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/views/location_disclosure_screen.dart';
import '../../language/views/language_selection_screen.dart';
import '../../language/viewmodels/language_vm.dart';
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
    final authUser = FirebaseAuth.instance.currentUser;

    // 🔒 Security: Ensure Auth Session Matches Local Data
    if (userId == null || authUser == null) {
      debugPrint("⚠️ Session Invalid or Missing. Redirecting to Login.");
      await UserPreferences.clearUserData();
      _navigateTo(const LanguageSelectionScreen());
      return;
    }

    // Sync FCM Token
    NotificationService().getDeviceToken().then((t) {
      if (t != null) NotificationService().saveTokenToDatabase(t);
    });

    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _navigateTo(const LocationDisclosureScreen());
      return;
    }

    try {
      // ── Always fetch LATEST ride for this user ──────────────────────────
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
          .orderBy('createdAt', descending: true) // ← Latest first
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        _navigateTo(const MainNavigator());
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final rideId = doc.id;
      final status = data['status'] as String?;
      final Timestamp? createdAt = data['createdAt'];

      if (status == null) {
        _navigateTo(const MainNavigator());
        return;
      }

      // ── Zombie / Stale Ride Guard ───────────────────────────────────────
      if (createdAt != null) {
        final diffMinutes =
            DateTime.now().difference(createdAt.toDate()).inMinutes;

        // Pending rides: no driver accepted in 15 min → cancel + home
        if (status == 'pending' && diffMinutes > 15) {
          debugPrint("🧟 Zombie pending ride ($diffMinutes min old). Auto-cancelling: $rideId");
          await FirebaseFirestore.instance
              .collection('rideRequests')
              .doc(rideId)
              .update({'status': 'cancelled', 'cancelReason': 'timeout_startup'});
          if (!mounted) return;
          _navigateTo(const MainNavigator());
          return;
        }

        // Active rides older than 6 hours are no longer automatically killed here because a long ride (200km+) can take many hours. 
        // We solely rely on the driver cross-verification logic directly below to determine if a ride is truly stale/abandoned.

        // Completed rides older than 10 min → skip summary, go home
        if (status == 'completed' && diffMinutes > 10) {
          debugPrint("⏩ Completed ride too old ($diffMinutes min). Skipping summary.");
          if (!mounted) return;
          _navigateTo(const MainNavigator());
          return;
        }
      }
      // ───────────────────────────────────────────────────────────────────

      // ── Driver Cross-Verification ───────────────────────────────────────
      // Only check for active (non-completed, non-pending) rides.
      // If driver's isOnTrip is false → driver finished/cancelled, user is stuck.
      if (status == 'accepted' || status == 'arrived' || status == 'in_progress') {
        final String? driverId = data['driverId'] as String?;
        if (driverId != null) {
          try {
            final driverDoc = await FirebaseFirestore.instance
                .collection('drivers')
                .doc(driverId)
                .get();

            final bool driverIsOnTrip =
                driverDoc.data()?['isOnTrip'] == true;
            final String? driverCurrentRide =
                driverDoc.data()?['currentRideId'] as String?;

            // Driver is NOT on a trip, or is on a DIFFERENT ride → mismatch
            if (!driverIsOnTrip || (driverCurrentRide != null && driverCurrentRide != rideId)) {
              debugPrint(
                "🔴 Driver mismatch! driverIsOnTrip=$driverIsOnTrip "
                "driverCurrentRideId=$driverCurrentRide userRideId=$rideId. "
                "Auto-cancelling user ride."
              );
              await FirebaseFirestore.instance
                  .collection('rideRequests')
                  .doc(rideId)
                  .update({
                    'status': 'cancelled',
                    'cancelReason': 'driver_not_on_trip',
                    'cancelledBy': 'system',
                  });
              if (!mounted) return;
              _navigateTo(const MainNavigator());
              return;
            }
          } catch (e) {
            // If driver doc read fails, don't block the user — just continue
            debugPrint("⚠️ Driver cross-check failed: $e");
          }
        }
      }
      // ───────────────────────────────────────────────────────────────────

      // Route to the correct screen based on status
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
        // accepted / arrived / in_progress → show live ride screen
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
    } catch (e) {
      debugPrint("Splash restore error: $e");
      if (!mounted) return;
      _navigateTo(const MainNavigator());
    }
  }

  void _showNoInternetDialog() {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(lang.getText('uiConnectionError')),
        content: Text(lang.getText('uiCheckInternet')),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _checkInternetAndStart();
            },
            child: Text(lang.getText('uiRetry')),
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
              Image.asset(
                "assets/images/app_logo.jpg",
                width: 200,
                errorBuilder: (context, error, stackTrace) => Text(
                  "RURBOO",
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
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
