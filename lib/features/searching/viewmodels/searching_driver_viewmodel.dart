import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';

import '../models/driver_model.dart';
import '../../navigation/views/main_navigator.dart';

class SearchingDriverViewModel extends ChangeNotifier {
  final String rideId;
  final LatLng pickupLatLng;

  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  Timer? _timeoutTimer;

  VoidCallback? onTimeout;
  Function(DriverModel driver, Map<String, dynamic> rideData)? onDriverFound;

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
          final Timestamp? createdAt = data['createdAt'];

          debugPrint("USER RIDE LISTENER: Status='$status', Driver='$driverId'");
          
          // ── Zombie Ride Guard ──────────────────────────────────────────────
          if (createdAt != null) {
            final diffMins = DateTime.now().difference(createdAt.toDate()).inMinutes;
            if (status == 'pending' && diffMins > 15) {
              debugPrint("🧟 SearchingVM: Ride is stale ($diffMins min). Auto-cancelling.");
              _handleTimeout();
              return;
            }
          }
          // ───────────────────────────────────────────────────────────────────

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

            onDriverFound?.call(driver, data);
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
    // Show reason dialog first
    final reasons = [
      'Change of plans',
      'Driver is too far',
      'Found another ride',
      'Booked by mistake',
      'Other',
    ];
    String? selectedReason;

    if (!context.mounted) return;
    final lang = Provider.of<LanguageViewModel>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        String? pickedReason;
        return StatefulBuilder(
          builder: (ctx, setDlgState) {
            return AlertDialog(
              title: Text(lang.getText('uiCancelRideTitle')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Please select a reason for cancellation:',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  RadioGroup<String>(
                    groupValue: pickedReason,
                    onChanged: (v) => setDlgState(() => pickedReason = v),
                    child: Column(
                      children: reasons.map((r) => ListTile(
                        title: Text(r),
                        leading: Radio<String>(value: r),
                        contentPadding: EdgeInsets.zero,
                        onTap: () => setDlgState(() => pickedReason = r),
                      )).toList(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: Text(lang.getText('uiBack')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: pickedReason == null
                      ? null
                      : () {
                          selectedReason = pickedReason;
                          Navigator.pop(dialogCtx, true);
                        },
                  child: Text(lang.getText('uiCancelRideBtn')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

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
          .update({
             'status': 'cancelled',
             'cancelledBy': 'user',
             'cancelReason': selectedReason ?? 'Other',
          });

      stopListening();

      if (context.mounted) {
        Navigator.pop(context); // dismiss progress
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

        onDriverFound?.call(driver, data);
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
