import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../language/viewmodels/language_vm.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../viewmodels/home_viewmodel.dart';
import '../../ride/views/ride_selection_screen.dart';
import '../models/location_result.dart';
import 'package:rurboo/features/home/views/search_location_screen.dart';
import '../../voice/viewmodels/voice_agent_viewmodel.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../../core/services/user_preferences.dart';
import '../../voice/models/voice_agent_state.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/map_styles.dart';
import '../../ride/viewmodels/ride_selection_viewmodel.dart';
import '../../ride/repositories/ride_selection_repository.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey? navBarKey;
  const HomeScreen({super.key, this.navBarKey});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final GlobalKey _pickupKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = Provider.of<HomeViewModel>(context, listen: false);
      final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
      final lang = Provider.of<LanguageViewModel>(context, listen: false);
      
      voice.init();
      
      // Track welcome status for sequencing
      bool welcomeFinished = false;

      vm.onServiceUnavailable = () async {
        if (!mounted) return;
        
        // Wait for welcome to finish if it's already in progress or about to start
        if (!welcomeFinished) {
           debugPrint("📢 Out-of-zone detected, but waiting for welcome to finish...");
           return; 
        }

        if (voice.state != VoiceAgentState.speaking) {
          voice.speak(lang.getText('voice_out_of_zone'));
        }
      };

      // 1. Initialize logic
      await vm.init(context);
      
      // 2. Clear initial greeting sequence
      Future.delayed(const Duration(seconds: 1), () async {
        if (mounted) {
          debugPrint("📢 Starting Welcome sequence...");
          await voice.speak(lang.getText('welcome_msg'));
          welcomeFinished = true;
          debugPrint("✅ Welcome finished. Checking for service availability...");
          
          // Re-trigger announcement if service is unavailable
          if (!vm.isServiceAvailable) {
            voice.speak(lang.getText('voice_out_of_zone'));
          }
        }
      });

      // Check for first time onboarding
      final isFirstTime = await UserPreferences.isFirstTime();
      if (isFirstTime) {
        _showOnboarding();
      }
    });
  }

  void _showOnboarding() {
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    _initTargets(lang);
    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: AppColors.primary,
      textSkip: lang.getText('skip'),
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        UserPreferences.setFirstTime(false);
      },
      onSkip: () {
        UserPreferences.setFirstTime(false);
        return true;
      },
    )..show(context: context);
  }

  void _initTargets(LanguageViewModel lang) {
    targets.add(
      TargetFocus(
        identify: "pickup",
        keyTarget: _pickupKey,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.getText('tut_pickup_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    lang.getText('tut_pickup_body'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );

    targets.add(
      TargetFocus(
        identify: "search",
        keyTarget: _searchKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang.getText('tut_search_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    lang.getText('tut_search_body'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );

    if (widget.navBarKey != null) {
      targets.add(
        TargetFocus(
          identify: "navBar",
          keyTarget: widget.navBarKey,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang.getText('tut_nav_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: Text(
                      lang.getText('tut_nav_body'),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return HomeBody(pickupKey: _pickupKey, searchKey: _searchKey);
  }
}

class HomeBody extends StatelessWidget {
  final GlobalKey pickupKey;
  final GlobalKey searchKey;
  const HomeBody({super.key, required this.pickupKey, required this.searchKey});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<HomeViewModel>(context);
    final lang = Provider.of<LanguageViewModel>(context);

    // Refresh pickup address whenever language changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.refreshPickupLanguage(lang.language);
    });

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
                  style: const TextStyle(fontSize: 16, ),
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
            style: Provider.of<ThemeProvider>(context).isDarkMode ? MapStyles.darkMapStyle : null,
            padding: EdgeInsets.only(
              bottom: vm.destination == null ? 280 : 200,
            ),
          ),

          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: GestureDetector(
              key: pickupKey,
              onTap: () => _openSearch(context, isDestination: false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
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
                            style: TextStyle(fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            vm.pickup?.address == 'current_location'
                              ? lang.getText('current_location')
                              : (vm.pickup?.address ?? lang.getText('current_location')),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Divider
                    Container(
                      height: 30,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    
                    // Theme Toggle
                    GestureDetector(
                      onTap: () {
                        final themeProvider = context.read<ThemeProvider>();
                        themeProvider.toggleTheme(!themeProvider.isDarkMode);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          context.watch<ThemeProvider>().isDarkMode ? Icons.light_mode : Icons.dark_mode_rounded, 
                          color: context.watch<ThemeProvider>().isDarkMode ? Colors.amber : AppColors.textSecondary, 
                          size: 22,
                        ),
                      ),
                    ),
                    
                    // Save pickup as Home/Work/Favourite
                    GestureDetector(
                      onTap: () {
                        final loc = vm.pickup;
                        if (loc != null) {
                          showSaveLocationSheet(context, loc, lang);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.bookmark_outline, size: 22),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.search, ),
                  ],
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: -0.5, end: 0, curve: Curves.easeOutBack),
            ),
          ),

          if (vm.destination == null)
            _searchBottomSheet(context, vm)
          else
            _confirmRideBottomSheet(context, vm),

          // Out of Zone Warning Overlay
          if (!vm.isServiceAvailable)
            _outOfZoneOverlay(context, vm, lang),
        ],
      ),
    );
  }

  Widget _outOfZoneOverlay(BuildContext context, HomeViewModel vm, LanguageViewModel lang) {
    return Positioned(
      bottom: vm.destination == null ? 350 : 250, // Above the bottom sheets
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lang.getText('service_unavailable_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lang.getText('service_unavailable_desc'),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openSearch(context, isDestination: false),
                icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
                label: Text(lang.getText('change_location')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ).animate().shake(duration: 500.ms),
    );
  }

  Widget _confirmRideBottomSheet(BuildContext context, HomeViewModel vm) {
    final lang = Provider.of<LanguageViewModel>(context);
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08),
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
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
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
                  icon: const Icon(Icons.close, ),
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
                    builder: (_) => ChangeNotifierProvider(
                      create: (_) => RideSelectionViewModel(repo: RideSelectionRepository()),
                      child: RideSelectionScreen(
                        pickupText: vm.pickupAddress == 'current_location' 
                            ? lang.getText('current_location') 
                            : (vm.pickupAddress ?? ""),
                        destinationText: vm.destinationAddress ?? "",
                        pickupLoc: vm.pickup!,
                        destinationLoc: vm.destination!,
                        distanceKm: distanceInKm,
                      ),
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
    final maxH = MediaQuery.of(context).size.height * 0.55;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 30,
              offset: const Offset(0, -5),
            )
          ],
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag handle ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── "Where to?" search box ───────────────────────────────
              GestureDetector(
                key: searchKey,
                onTap: () => _openSearch(context, isDestination: true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? Colors.grey[850] : const Color(0xFFF4F7F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.dividerColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: AppColors.primary, size: 24),
                      const SizedBox(width: 16),
                      Text(
                        lang.getText('where_to'),
                        style: theme.textTheme.titleMedium?.copyWith(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Home / Work shortcuts ────────────────────────────────
              Row(
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

              // ── Favourite locations (horizontal scroll) ──────────────
              if (vm.favoriteLocations.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  lang.getText('favorites'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: vm.favoriteLocations.length,
                    itemBuilder: (context, i) {
                      final fav = vm.favoriteLocations[i];
                      return GestureDetector(
                        onTap: () => vm.selectDestination(fav),
                        child: Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.favorite, size: 18, color: Colors.deepPurple),
                              const SizedBox(height: 4),
                              Text(
                                fav.address.split(',').first,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // ── Recent Destinations ──────────────────────────────────
              const SizedBox(height: 16),
              Text(
                lang.getText('recent_destinations'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),

              if (vm.recentDestinations.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.history, size: 24, ),
                      const SizedBox(width: 8),
                      Text(
                        lang.getText('no_recent_destinations'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 135),
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: vm.recentDestinations.length,
                    separatorBuilder: (c, i) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dest = vm.recentDestinations[index];
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.canvasColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history, size: 16, color: AppColors.primary),
                        ),
                        title: Text(
                          dest.address.split(',').first,
                          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          dest.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.bookmark_outline, size: 16, ),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final loc = LocationResult(
                              address: dest.address,
                              coordinates: dest.latLng,
                            );
                            showSaveLocationSheet(context, loc, lang, onSaved: () {
                              vm.reloadSavedLocations();
                            });
                          },
                        ),
                        onTap: () => vm.selectDestination(
                          LocationResult(
                            address: dest.address,
                            coordinates: dest.latLng,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
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
                      style: TextStyle(fontSize: 11),
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

    final raw = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => SearchLocationScreen(
          isDestination: isDestination,
          existingPickupAddress: vm.pickupAddress,
          existingDestinationAddress: vm.destinationAddress,
        ),
      ),
    );

    if (raw == null || !context.mounted) return;

    // New format: Map with 'result' and 'isDestination'
    // Legacy format (just a LocationResult): treat as destination
    LocationResult? result;
    bool setAsDestination = isDestination;

    if (raw is Map) {
      result = raw['result'] as LocationResult?;
      setAsDestination = raw['isDestination'] as bool? ?? isDestination;
    } else if (raw is LocationResult) {
      result = raw;
    }

    if (result == null) return;

    if (setAsDestination) {
      await vm.selectDestination(result);
    } else {
      await vm.setPickupLocation(result, context: context);
    }
  }
}

