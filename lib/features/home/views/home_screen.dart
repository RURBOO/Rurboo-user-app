import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../ride/views/ride_selection_screen.dart';
import '../models/location_result.dart';
import 'search_destination_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<HomeViewModel>(context, listen: false).init(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const HomeBody();
  }
}

class HomeBody extends StatelessWidget {
  const HomeBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<HomeViewModel>(context);

    if (vm.hasLocationError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_disabled,
                  size: 60,
                  color: Colors.red,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Location Required",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "We need your precise location to book rides. "
                  "Please enable GPS and allow location permissions.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => vm.init(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text("Retry"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                ),
                TextButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (vm.permissionDenied) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                const Text(
                  "Location Permission Required",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "To book a ride, we need to access your location.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => vm.init(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Allow Location"),
                ),
                TextButton(
                  onPressed: () => Geolocator.openAppSettings(),
                  child: const Text("Open Settings"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (vm.loadingLocation || vm.currentLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: vm.onMapCreated,
            initialCameraPosition: CameraPosition(
              target: vm.currentLocation!,
              zoom: 15,
            ),
            markers: vm.markers,
            polylines: vm.polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            padding: EdgeInsets.only(
              bottom: vm.destination == null ? 280 : 200,
            ),
          ),

          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.my_location, color: Colors.black54),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vm.pickup?.address ?? "Current Location",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: vm.destination == null ? 320 : 200,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: () {
                if (vm.currentLocation != null) {
                  vm.mapController?.animateCamera(
                    CameraUpdate.newLatLng(vm.currentLocation!),
                  );
                }
              },
              child: const Icon(Icons.my_location, color: Colors.black),
            ),
          ),

          vm.destination == null
              ? _searchBottomSheet(context, vm)
              : _confirmRideBottomSheet(context, vm),
        ],
      ),
    );
  }

  Widget _searchBottomSheet(BuildContext context, HomeViewModel vm) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 280,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 60,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openSearchForDestination(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text("Where to?", style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Recent Destinations",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: vm.recentDestinations.isEmpty
                  ? const Center(
                      child: Text(
                        "No recent destinations yet",
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: vm.recentDestinations.length,
                      itemBuilder: (_, index) {
                        final place = vm.recentDestinations[index];
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(
                            place.address,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => vm.selectDestination(
                            LocationResult(
                              address: place.address,
                              coordinates: place.latLng,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _confirmRideBottomSheet(BuildContext context, HomeViewModel vm) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                vm.destination?.address ?? "",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => vm.clearDestination(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (vm.pickupLatLng == null || vm.destinationLatLng == null) {
                  return;
                }

                final distanceInMeters = Geolocator.distanceBetween(
                  vm.pickupLatLng!.latitude,
                  vm.pickupLatLng!.longitude,
                  vm.destinationLatLng!.latitude,
                  vm.destinationLatLng!.longitude,
                );
                final distanceInKm = distanceInMeters / 1000;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideSelectionScreen(
                      pickupText: vm.pickupAddress!,
                      destinationText: vm.destinationAddress!,
                      pickupLoc: vm.pickup!,
                      destinationLoc: vm.destination!,
                      distanceKm: distanceInKm,
                    ),
                  ),
                );
              },
              child: const Text("Confirm Ride", style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchForDestination(BuildContext context) async {
    final vm = Provider.of<HomeViewModel>(context, listen: false);
    final result = await Navigator.push<LocationResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchLocationScreen(
          isDestination: true,
          existingPickupAddress: vm.pickupAddress,
          existingDestinationAddress: vm.destinationAddress,
        ),
      ),
    );

    if (result != null) {
      await vm.selectDestination(result);
    }
  }
}
