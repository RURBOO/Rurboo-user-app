import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../ride/views/ride_selection_screen.dart';
import '../models/location_result.dart';
import 'package:rurboo/features/home/views/search_destination_screen.dart';
import '../../voice/viewmodels/voice_agent_viewmodel.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      
      // Initialize voice service for announcements only (no commands)
      final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
      voice.init();
      
      // Welcome announcement
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          final lang = Provider.of<LanguageViewModel>(context, listen: false);
          voice.speak(lang.getText('welcome_msg'));
        }
      });
    });
  }
  
  @override
  void dispose() {
    super.dispose();
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
    final lang = Provider.of<LanguageViewModel>(context);

    if (vm.hasLocationError) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off_rounded,
                  size: 80,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 24),
                Text(
                  lang.getText('location_required'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  lang.getText('enable_gps'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => vm.init(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(lang.getText('try_again')),
                  ),
                ),

                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    openAppSettings();
                  },
                  child: Text(lang.getText('open_settings')),
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
            top: 60,
            left: 20,
            right: 20,
            child: GestureDetector(
              onTap: () => _openSearch(context, isDestination: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30), // Pill Shape
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.my_location, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            lang.getText('pickup_from'),
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vm.pickup?.address ?? lang.getText('current_location'),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 30, 
                      width: 1, 
                      color: Colors.grey[200], 
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    const Icon(Icons.search, color: AppColors.textSecondary),
                  ],
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: -0.5, end: 0, curve: Curves.easeOutBack),
            ),
          ),

          if (vm.destination == null)
            _searchBottomSheet(context, vm)
          else
            _confirmRideBottomSheet(context, vm),
        ],
      ),
    );
  }

  Widget _confirmRideBottomSheet(BuildContext context, HomeViewModel vm) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    vm.destination?.address ?? "",
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => vm.clearDestination(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
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
              child: Text(lang.getText('confirm_ride')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBottomSheet(BuildContext context, HomeViewModel vm) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 320,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 24),
            
            // Where to Box
            GestureDetector(
              onTap: () => _openSearch(context, isDestination: true),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.primary, size: 24),
                    const SizedBox(width: 16),
                    Text(
                      lang.getText('where_to'),
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Home/Work shortcuts
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  _shortcutChip(
                    context,
                    icon: Icons.home_rounded,
                    label: lang.getText('home'),
                    color: Colors.blue,
                    location: vm.homeLocation,
                    onTap: () {
                      if (vm.homeLocation != null) {
                        vm.selectDestination(vm.homeLocation!);
                      } else {
                        _openSearch(context, isDestination: true);
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _shortcutChip(
                    context,
                    icon: Icons.work_rounded,
                    label: lang.getText('work'),
                    color: Colors.orange,
                    location: vm.workLocation,
                    onTap: () {
                      if (vm.workLocation != null) {
                        vm.selectDestination(vm.workLocation!);
                      } else {
                        _openSearch(context, isDestination: true);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Recent Destinations Title
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lang.getText('recent_destinations'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Recent List
            Expanded(
              child: vm.recentDestinations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 40, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text(
                            lang.getText('no_recent_destinations'),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: vm.recentDestinations.length,
                      separatorBuilder: (c, i) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final destination = vm.recentDestinations[index];
                        return InkWell(
                          onTap: () => vm.selectDestination(
                            LocationResult(
                              address: destination.address,
                              coordinates: destination.latLng,
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.location_on_outlined, size: 20, color: AppColors.primary),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      destination.address.split(',').first,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      destination.address,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
    );
  }

  Widget _shortcutChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    LocationResult? location,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      location?.address.split(',').first ?? Provider.of<LanguageViewModel>(context).getText('add_favorite'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch(
    BuildContext context, {
    required bool isDestination,
  }) async {
    final vm = Provider.of<HomeViewModel>(context, listen: false);

    final result = await Navigator.push<LocationResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchLocationScreen(
          isDestination: isDestination,
          existingPickupAddress: vm.pickupAddress,
          existingDestinationAddress: vm.destinationAddress,
        ),
      ),
    );

    if (result != null) {
      if (isDestination) {
        await vm.selectDestination(result);
      } else {
        await vm.setPickupLocation(result);
      }
    }
  }
}
