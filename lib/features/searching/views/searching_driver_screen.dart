import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../language/viewmodels/language_vm.dart';

import '../../navigation/views/main_navigator.dart';
import '../../../core/theme/map_styles.dart';
import '../../../core/theme/theme_provider.dart';
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

    vm.onDriverFound = (driver, rideData) {
      if (!mounted) return;

      final ride = RideBookingModel(
        driverName: driver.name,
        driverPhone: driver.driverPhone,
        carName: driver.carName,
        carNumber: driver.carNumber,
        rating: driver.rating,
        fare: (rideData['finalFare'] ?? rideData['fare'] ?? 0).toDouble(),
        paymentMethod: rideData['paymentMethod'] ?? "Cash",
        discountAmount: (rideData['discountAmount'] ?? 0).toDouble(),
        couponCode: rideData['couponCode'],
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
      final lang = Provider.of<LanguageViewModel>(context, listen: false);
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text(lang.getText('no_drivers_available')),
          content: Text(lang.getText('no_drivers_desc')),
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
              child: Text(lang.getText('ok')),
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
    final lang = Provider.of<LanguageViewModel>(context);

     return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.getText('cancel_to_go_back')),
            duration: const Duration(seconds: 2),
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
                  infoWindow: InfoWindow(
                    title: lang.getText('pickup_label'),
                    snippet: (widget.pickupAddress == 'current_location' || widget.pickupAddress == 'Current Location')
                        ? lang.getText('current_location')
                        : widget.pickupAddress,
                  ),
                ),
              },
              zoomControlsEnabled: false,
              style: Provider.of<ThemeProvider>(context).isDarkMode ? MapStyles.darkMapStyle : null,
            ),

            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.38, // Reduced from 0.45
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), // Compact padding
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 50, // Smaller handle
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 12), // Reduced spacing

                    Text(
                      lang.getText('searching_driver'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16, // Reduced from 17
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10), // Reduced spacing

                    SizedBox(
                      height: 130, // Reduced from 160
                      width: 130,
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
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            (widget.pickupAddress == 'current_location' || widget.pickupAddress == 'Current Location')
                                ? lang.getText('current_location')
                                : widget.pickupAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
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
                          
                          side: BorderSide(
                            color: Colors.red.shade400,
                            width: 2,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          lang.getText('cancel_ride'),
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
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [_circle(60), _circle(90), _circle(120), widget.child],
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
        color: Colors.amber.withValues(alpha: 0.3 * (1 - value)),
      ),
    );
  }
}
