import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../navigation/views/main_navigator.dart';
import '../../ride/views/ride_booked_screen.dart';
import '../viewmodels/searching_driver_viewmodel.dart';
import '../../ride/models/ride_booking.dart';

class SearchingDriverScreen extends StatefulWidget {
  final String rideId;
  final LatLng pickupLatLng;
  final String pickupAddress;
  final LatLng destinationLatLng;
  final String destinationAddress;

  const SearchingDriverScreen({
    super.key,
    required this.rideId,
    required this.pickupLatLng,
    required this.pickupAddress,
    required this.destinationLatLng,
    required this.destinationAddress,
  });

  @override
  State<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends State<SearchingDriverScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SearchingDriverViewModel(
        rideId: widget.rideId,
        pickupLatLng: widget.pickupLatLng,
      ),
      child: _SearchingDriverBody(
        rideId: widget.rideId,
        pickupLatLng: widget.pickupLatLng,
        pickupAddress: widget.pickupAddress,
        destinationLatLng: widget.destinationLatLng,
        destinationAddress: widget.destinationAddress,
      ),
    );
  }
}

class _SearchingDriverBody extends StatefulWidget {
  final String rideId;
  final LatLng pickupLatLng;
  final String pickupAddress;
  final LatLng destinationLatLng;
  final String destinationAddress;

  const _SearchingDriverBody({
    required this.rideId,
    required this.pickupLatLng,
    required this.pickupAddress,
    required this.destinationLatLng,
    required this.destinationAddress,
  });

  @override
  State<_SearchingDriverBody> createState() => _SearchingDriverBodyState();
}

class _SearchingDriverBodyState extends State<_SearchingDriverBody>
    with WidgetsBindingObserver {
  late SearchingDriverViewModel vm;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    vm = Provider.of<SearchingDriverViewModel>(context, listen: false);

    vm.onDriverFound = (driver) {
      if (!mounted) return;

      final ride = RideBookingModel(
        driverName: driver.name,
        driverPhone: driver.driverPhone,
        carName: driver.carName,
        carNumber: driver.carNumber,
        rating: driver.rating,
        fare: 201,
        paymentMethod: "Cash",
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RideBookedScreen(
            pickupLatLng: widget.pickupLatLng,
            pickupAddress: widget.pickupAddress,
            destinationLatLng: widget.destinationLatLng,
            destinationAddress: widget.destinationAddress,
            ride: ride,
            rideId: widget.rideId,
          ),
        ),
      );
    };

    vm.onTimeout = () {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("No Drivers Available"),
          content: const Text(
            "We couldn't find a driver nearby. Please try again later.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavigator()),
                  (r) => false,
                );
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );
    };

    vm.startListeningForDriver();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("App resumed → forcing driver status refresh");
      vm.checkForUpdates();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<SearchingDriverViewModel>(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please cancel the ride to go back"),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: widget.pickupLatLng,
                zoom: 15.5,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: widget.pickupLatLng,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              },
              zoomControlsEnabled: false,
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "Contacting nearby drivers...",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      height: 160,
                      width: 160,
                      child: RippleAnimation(
                        child: const CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.black,
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            widget.pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => vm.cancelRide(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.red.shade400,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          "Cancel Ride",
                          style: TextStyle(
                            color: Colors.red.shade400,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RippleAnimation extends StatefulWidget {
  final Widget child;
  const RippleAnimation({super.key, required this.child});

  @override
  State<RippleAnimation> createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<RippleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [_circle(80), _circle(110), _circle(140), widget.child],
          );
        },
      ),
    );
  }

  Widget _circle(double maxSize) {
    final value = _controller.value;
    return Container(
      width: maxSize * value,
      height: maxSize * value,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.amber.withOpacity(0.3 * (1 - value)),
      ),
    );
  }
}
