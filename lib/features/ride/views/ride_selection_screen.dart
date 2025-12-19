import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/user_preferences.dart';

import '../../home/models/location_result.dart';
import '../viewmodels/ride_selection_viewmodel.dart';
import '../repositories/ride_selection_repository.dart';
import '../models/ride_options.dart';
import '../../searching/views/searching_driver_screen.dart';
import 'dart:math';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';

class RideSelectionScreen extends StatefulWidget {
  final String pickupText;
  final String destinationText;
  final LocationResult pickupLoc;
  final LocationResult destinationLoc;
  final double distanceKm;

  const RideSelectionScreen({
    super.key,
    required this.pickupText,
    required this.destinationText,
    required this.pickupLoc,
    required this.destinationLoc,
    required this.distanceKm,
  });

  @override
  State<RideSelectionScreen> createState() => _RideSelectionScreenState();
}

class _RideSelectionScreenState extends State<RideSelectionScreen> {
  bool _isInit = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RideSelectionViewModel(repo: RideSelectionRepository()),
      child: Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_isInit) {
              _isInit = true;
              final vm = Provider.of<RideSelectionViewModel>(
                context,
                listen: false,
              );
              vm.init(
                pickupLoc: widget.pickupLoc,
                destLoc: widget.destinationLoc,
                distance: widget.distanceKm,
              );
            }
          });

          return const RideSelectionBody();
        },
      ),
    );
  }
}

class RideSelectionBody extends StatelessWidget {
  const RideSelectionBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<RideSelectionViewModel>(context);
    final yellow = Colors.amber.shade700;

    final parent = context.findAncestorWidgetOfExactType<RideSelectionScreen>();

    if (vm.loading || parent == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Select a Ride"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.40,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: vm.pickup.coordinates!,
                zoom: 13,
              ),
              onMapCreated: (c) => vm.setMapController(c),
              markers: vm.markers,
              polylines: vm.polylines,
              zoomControlsEnabled: false,
              myLocationEnabled: false,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            ),
          ),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _locationPreview(parent.pickupText, parent.destinationText),

                  const SizedBox(height: 12),

                  if (vm.isOutstationRide)
                    _outstationMessage()
                  else
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Available Rides",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: vm.rideOptions.length,
                              itemBuilder: (_, i) {
                                final ride = vm.rideOptions[i];
                                final selected = vm.selectedRide == ride;
                                return GestureDetector(
                                  onTap: () => vm.selectRide(ride),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.amber[50]
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? yellow
                                            : Colors.grey[300]!,
                                        width: selected ? 2 : 1,
                                      ),
                                    ),
                                    child: _rideTile(ride, selected, yellow),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),
                  _paymentDisplay(),
                  const SizedBox(height: 12),
                  _confirmButton(context, vm, yellow),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _locationPreview(String pickup, String destination) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 14),
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
                const Icon(Icons.square, color: Colors.red, size: 14),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pickup,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    destination,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmButton(
    BuildContext context,
    RideSelectionViewModel vm,
    Color yellow,
  ) {
    final bool isButtonDisabled =
        vm.isBooking || vm.isOutstationRide || vm.selectedRide == null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isButtonDisabled
            ? null
            : () async {
                await vm.bookRide(() async {
                  await _bookRide(context, vm);
                });
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: yellow,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: vm.isBooking
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                vm.isOutstationRide
                    ? "Beyond Service Limit"
                    : (vm.selectedRide == null
                          ? "Select a Ride"
                          : "Book ${vm.selectedRide!.name}"),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
      ),
    );
  }

  Widget _outstationMessage() =>
      const Center(child: Text("Outstation Rides Not Available"));

  Widget _paymentDisplay() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: const [
      Text("Payment Method", style: TextStyle(fontWeight: FontWeight.w600)),
      Text("Cash", style: TextStyle(fontWeight: FontWeight.bold)),
    ],
  );

  Widget _rideTile(RideOption ride, bool selected, Color yellow) {
    return Row(
      children: [
        Icon(ride.icon, color: selected ? yellow : Colors.black54),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(ride.description, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        Text(
          "₹${ride.fare.toStringAsFixed(0)}",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _bookRide(
    BuildContext context,
    RideSelectionViewModel vm,
  ) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No Internet Connection"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = await UserPreferences.getUserId();
      if (userId == null || vm.selectedRide == null) {
        throw Exception("Invalid booking state");
      }

      final GeoFirePoint pickupGeo = GeoFirePoint(
        GeoPoint(
          vm.pickup.coordinates!.latitude,
          vm.pickup.coordinates!.longitude,
        ),
      );

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) throw Exception("User not found");
      final userData = userDoc.data()!;

      final parent = context
          .findAncestorWidgetOfExactType<RideSelectionScreen>();
      final String otp = (1000 + Random().nextInt(9000)).toString();

      String rideName = vm.selectedRide!.name.toLowerCase();
      String category = "Car";

      if (rideName.contains("bike") || rideName.contains("moto")) {
        category = "Bike";
      } else if (rideName.contains("auto") || rideName.contains("rickshaw")) {
        category = "Auto";
      }

      final rideData = {
        'userId': userId,
        'userName': userData['name'] ?? 'User',
        'userPhone': userData['phoneNumber'] ?? '',
        'pickupAddress': parent?.pickupText,
        'destinationAddress': parent?.destinationText,
        'pickupGeo': pickupGeo.data,
        'pickupCoords': GeoPoint(
          vm.pickup.coordinates!.latitude,
          vm.pickup.coordinates!.longitude,
        ),
        'destinationCoords': GeoPoint(
          vm.destination.coordinates!.latitude,
          vm.destination.coordinates!.longitude,
        ),
        'fare': vm.selectedRide!.fare,
        'rideType': vm.selectedRide!.name,
        'vehicleCategory': category,
        'paymentMethod': vm.selectedPayment,
        'otp': otp,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final ref = await FirebaseFirestore.instance
          .collection('rideRequests')
          .add(rideData);

      if (context.mounted) {
        Navigator.pop(context);

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => SearchingDriverScreen(
              rideId: ref.id,
              pickupLatLng: vm.pickup.coordinates!,
              pickupAddress: parent?.pickupText ?? "",
              destinationLatLng: vm.destination.coordinates!,
              destinationAddress: parent?.destinationText ?? "",
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Booking failed: $e")));
      }
    }
  }
}
