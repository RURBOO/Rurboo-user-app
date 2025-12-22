import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../navigation/views/main_navigator.dart';
import '../viewmodels/ride_booked_viewmodel.dart';
import '../repositories/ride_booked_repository.dart';
import '../../home/services/polyline_service.dart';
import '../models/ride_booking.dart';
import 'ride_summary_screen.dart';

class RideBookedScreen extends StatefulWidget {
  final LatLng pickupLatLng;
  final String pickupAddress;
  final LatLng destinationLatLng;
  final String destinationAddress;
  final RideBookingModel ride;
  final String rideId;

  const RideBookedScreen({
    super.key,
    required this.pickupLatLng,
    required this.pickupAddress,
    required this.destinationLatLng,
    required this.destinationAddress,
    required this.ride,
    required this.rideId,
  });

  @override
  State<RideBookedScreen> createState() => _RideBookedScreenState();
}

class _RideBookedScreenState extends State<RideBookedScreen> {
  late RideBookedViewModel vm;

  @override
  void initState() {
    super.initState();

    vm = RideBookedViewModel(
      repo: RideBookedRepository(polyService: PolylineService()),
      rideId: widget.rideId,
      pickupLatLng: widget.pickupLatLng,
      destinationLatLng: widget.destinationLatLng,
      pickupAddress: widget.pickupAddress,
      destinationAddress: widget.destinationAddress,
      rideDetails: widget.ride,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.init();

      vm.onRideCancelled = (bool isDriver) {
        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigator()),
          (r) => false,
        );

        if (isDriver) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ride was cancelled by the driver."),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ride cancelled."),
              backgroundColor: Colors.grey,
            ),
          );
        }
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RideBookedViewModel>.value(
      value: vm,
      child: const _RideBookedContent(),
    );
  }
}

class _RideBookedContent extends StatelessWidget {
  const _RideBookedContent();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RideBookedViewModel>();

    if (vm.stage == RideStage.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => RideSummaryScreen(
              rideId: vm.rideId,
              fare: vm.rideDetails?.fare ?? 0,
              driverName: vm.rideDetails?.driverName ?? "Driver",
            ),
          ),
        );
      });
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please complete or cancel the ride to exit"),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: vm.pickupLatLng,
                zoom: 15,
              ),
              onCameraMoveStarted: () {
                vm.onUserPanMap();
              },
              onMapCreated: vm.setMapController,
              markers: vm.markers,
              polylines: vm.polylines,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              padding: const EdgeInsets.only(bottom: 300, top: 80),
            ),

            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(),

                    FloatingActionButton.small(
                      heroTag: 'share_btn',
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 3,
                      child: const Icon(Icons.share, size: 20),
                      onPressed: () {
                        Share.share(
                          "Tracking my ride on Rubo! ID: ${vm.rideId}",
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            Positioned(
              top: 100,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'sos_btn',
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                onPressed: () => vm.triggerSOS(),
                child: const Icon(Icons.sos),
              ),
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.50,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 35,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vm.rideDetails?.driverName ??
                                        "Connecting...",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "${vm.rideDetails?.carName} • ${vm.rideDetails?.carNumber}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        vm.rideDetails?.rating.toString() ??
                                            "5.0",
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            if (vm.stage == RideStage.arriving &&
                                vm.otp != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    const Text(
                                      "OTP",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      vm.otp!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _getStatusText(vm.stage),
                              style: TextStyle(
                                color: vm.stage == RideStage.arriving
                                    ? Colors.blue[700]
                                    : Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (vm.stage == RideStage.arriving ||
                                vm.stage == RideStage.inProgress)
                              Text(
                                vm.eta,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 15),

                        _buildTripLine(vm),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  color: Colors.green,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  vm.rideDetails?.paymentMethod ?? "Cash",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "₹${vm.rideDetails?.fare.toStringAsFixed(0) ?? '0'}",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _showCancelDialog(context, vm),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.close),
                                label: const Text("Cancel"),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => vm.callDriver(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.call),
                                label: const Text("Call Driver"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(RideStage stage) {
    switch (stage) {
      case RideStage.arriving:
        return "Driver is arriving";
      case RideStage.inProgress:
        return "Heading to destination";
      case RideStage.completed:
        return "Ride Completed";
      case RideStage.cancelled:
        return "Ride Cancelled";
      default:
        return "Connecting...";
    }
  }

  Widget _buildTripLine(RideBookedViewModel vm) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const Icon(Icons.circle, size: 14, color: Colors.green),
              Expanded(
                child: Container(
                  width: 2,
                  color: Colors.grey[300],
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
              const Icon(Icons.square, size: 14, color: Colors.red),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  vm.pickupAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
                const SizedBox(height: 20),
                Text(
                  vm.destinationAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, RideBookedViewModel vm) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Cancel Ride?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "Are you sure you want to cancel? This might affect your rating.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final connectivity = await Connectivity().checkConnectivity();
                  if (connectivity.contains(ConnectivityResult.none)) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("No Internet! Cannot cancel ride."),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  vm.cancelRide();
                  Navigator.pop(context);
                },
                child: const Text("Yes, Cancel Ride"),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Don't Cancel",
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
