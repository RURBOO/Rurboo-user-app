import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/user_preferences.dart';
import '../../language/viewmodels/language_vm.dart';

import '../../home/models/location_result.dart';
import '../viewmodels/ride_selection_viewmodel.dart';
import '../repositories/ride_selection_repository.dart';
import '../models/ride_options.dart';
import '../../searching/views/searching_driver_screen.dart';
import 'dart:math';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import '../../voice/viewmodels/voice_agent_viewmodel.dart';

import '../../voice/services/voice_intent_parser.dart'; // Added
import '../../voice/models/voice_agent_state.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/map_styles.dart';
import '../../../core/theme/theme_provider.dart';

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
  VoiceAgentViewModel? _voiceVM; // Keep ref for dispose

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
              ).then((_) async {
                 // Announce ALL vehicle fares comprehensively
                 if (context.mounted && vm.rideOptions.isNotEmpty) {
                    final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
                    final lang = Provider.of<LanguageViewModel>(context, listen: false);
                    
                    // Translate dynamic arguments first
                    final translatedLocations = await lang.translate([widget.pickupText, widget.destinationText]);
                    final pickupTranslated = translatedLocations.isNotEmpty ? translatedLocations[0] : widget.pickupText;
                    final destinationTranslated = translatedLocations.length > 1 ? translatedLocations[1] : widget.destinationText;

                    // Build vehicle list for announcement
                    List<Map<String, dynamic>> vehicles = [];
                    for(var ride in vm.rideOptions) {
                        final transNames = await lang.translate([ride.name]);
                        vehicles.add({
                          'name': transNames.isNotEmpty ? transNames[0] : ride.name,
                          'fare': ride.fare.toInt(),
                          'id': ride.id,
                        });
                    }
                    
                    // Announce pickup, destination, distance, and all vehicle fares
                    voice.announceAllVehicleFares(
                      pickup: pickupTranslated,
                      destination: destinationTranslated,
                      distanceKm: widget.distanceKm,
                      vehicles: vehicles,
                    );
                 }
              });
              
              // Voice Listener
              _voiceVM = Provider.of<VoiceAgentViewModel>(context, listen: false);
              _voiceVM!.addListener(_onVoiceUpdate);
            }
          });

          return const RideSelectionBody();
        },
      ),
    );
  }

  void _onVoiceUpdate() {
     if (!mounted) return;
     final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
     final vm = Provider.of<RideSelectionViewModel>(context, listen: false);
     final lang = Provider.of<LanguageViewModel>(context, listen: false);
     
     // 1. Vehicle Logic: Selection OR Negation
     if (voice.lastIntent?.type == IntentType.booking) {
        final intent = voice.lastIntent!;
        
        // A. Negation handling ("Bike nahi chahiye")
        if (intent.negatedVehicle != null) {
            final negated = intent.negatedVehicle!.toLowerCase();
            
            // If currently selected ride matches negated, switch to something else (default Auto)
            if (vm.selectedRide?.name.toLowerCase().contains(negated) == true) {
               // Try to Switch to Auto if not Auto, else Car
               RideOption? fallback;
               try {
                 fallback = vm.rideOptions.firstWhere((r) => !r.name.toLowerCase().contains(negated));
               } catch (_) {}
               
               if (fallback != null) {
                  vm.selectRide(fallback);
                  final msg = lang.getText('voice_vehicle_selected')
                      .replaceAll('{vehicle}', lang.getText(fallback.name));
                  voice.speak(msg);
               } else {
                  voice.speak(lang.getText('voice_no_other_vehicles'));
               }
               voice.consumeIntent();
               return; // Exit
            }
        }

        // B. Selection handling ("Auto chahiye")
        if (intent.vehicle != null) {
            final requestedVehicle = intent.vehicle!.toLowerCase();
            
            // Find matching ride
            try {
               final ride = vm.rideOptions.firstWhere(
                 (r) => r.name.toLowerCase().contains(requestedVehicle)
               );
               
               if (vm.selectedRide != ride) {
                 vm.selectRide(ride);
                 final msg = lang.getText('voice_fare_confirm')
                     .replaceAll('{vehicle}', lang.getText(ride.name))
                     .replaceAll('{fare}', ride.fare.toInt().toString());
                 voice.speak(msg);
                 voice.consumeIntent(); // Prevent Loop
               }
            } catch (e) {
               // Vehicle not found
               if (voice.state != VoiceAgentState.speaking) {
                   final msg = lang.getText('voice_vehicle_not_available')
                       .replaceAll('{vehicle}', requestedVehicle);
                   voice.speak(msg);
                   voice.consumeIntent();
               }
            }
        }
     }
     
     // 2. Handle Confirmation ("Haan", "Thik hai") -> Book
     if (voice.lastIntent?.type == IntentType.confirm && voice.state == VoiceAgentState.confirmingFare) {
         if (!vm.isBooking && vm.selectedRide != null) {
            voice.speak(lang.getText('voice_booking_confirmed'));
            voice.consumeIntent();
            
            vm.bookRide(() async {
               await bookRideTransaction(
                 context, 
                 vm, 
                 pickupText: widget.pickupText, 
                 destinationText: widget.destinationText
               );
            });
         }
     }
     
     // 3. Handle Cancellation ("Cancel karo")
     if (voice.lastIntent?.type == IntentType.cancel) {
        if (!vm.isBooking) {
            voice.speak(lang.getText('voice_selection_cancelled'));
            voice.consumeIntent();
            Navigator.pop(context); // Go back to home
        }
     }
  }

  @override
  void dispose() {
    _voiceVM?.removeListener(_onVoiceUpdate);
    super.dispose();
  }

}

class RideSelectionBody extends StatelessWidget {
  const RideSelectionBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<RideSelectionViewModel>(context);
    final lang = Provider.of<LanguageViewModel>(context);
    // REMOVED UNUSED YELLOW

    final parent = context.findAncestorWidgetOfExactType<RideSelectionScreen>();

    if (vm.loading || parent == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // Allow map to go behind app bar
      appBar: AppBar(
        title: Text(lang.getText('select_ride'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white.withValues(alpha: 0.9), // Fixed
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // MAP BACKGROUND
          Positioned.fill(
            bottom: 0, // Extend to bottom
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: vm.pickup.coordinates!,
                zoom: 14,
              ),
              onMapCreated: (c) => vm.setMapController(c),
              markers: vm.markers,
              polylines: vm.polylines,
              zoomControlsEnabled: false,
              myLocationEnabled: false,
              style: Provider.of<ThemeProvider>(context).isDarkMode ? MapStyles.darkMapStyle : null,
              // Add padding so logo/legal buttons appear above the minimized sheet (approx 35% height)
              padding: EdgeInsets.only(
                top: 40, 
                left: 20, 
                right: 20, 
                bottom: MediaQuery.of(context).size.height * 0.38
              ),
            ),
          ),

          // BOTTOM SHEET (Draggable List Only)
          DraggableScrollableSheet(
            initialChildSize: 0.70, // Reduced from 0.80
            minChildSize: 0.55,     // Reduced from 0.65
            maxChildSize: 0.88, // Reduced from 0.95 to limit upward scroll
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), // Compact padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 30,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    
                    _locationPreview(parent.pickupText, parent.destinationText),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                             lang.getText('available_rides'),
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20)
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.compare_arrows, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  "${vm.distanceKm.toStringAsFixed(1)} ${lang.getText('km')}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (vm.isOutstationRide)
                       _outstationMessage(lang)
                    else if (!vm.isServiceAvailable)
                       _serviceUnavailableMessage(lang)
                    else
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                             Provider.of<VoiceAgentViewModel>(context, listen: false).stopAnnouncement();
                          },
                          child: ListView.separated(
                          controller: scrollController,
                          // Increased padding to 35% to ensure last items are visible above the fixed footer
                          padding: EdgeInsets.only(bottom: MediaQuery.of(context).size.height * 0.35), 
                          itemCount: vm.rideOptions.length,
                          separatorBuilder: (c, i) => const SizedBox(height: 12),
                          itemBuilder: (_, i) {
                            final ride = vm.rideOptions[i];
                            final selected = vm.selectedRide == ride;
                            
                            final voiceVM = Provider.of<VoiceAgentViewModel>(context);
                            final isHighlighted = voiceVM.highlightedElementId == ride.id;
                            
                            return GestureDetector(
                              onTap: () {
                                 HapticFeedback.selectionClick();
                                 Provider.of<VoiceAgentViewModel>(context, listen: false).stopAnnouncement();
                                 vm.selectRide(ride);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.primary.withValues(alpha: 0.05) :Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isHighlighted 
                                        ? const Color(0xFFFFD54F) 
                                        : (selected ? AppColors.primary : Colors.grey[200]!),
                                    width: isHighlighted ? 3 : (selected ? 2 : 1),
                                  ),
                                  boxShadow: isHighlighted 
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                          )
                                        ]
                                      : (selected ? [
                                     BoxShadow(color: AppColors.primary.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))
                                  ] : []),
                                ),
                                  child: _rideTile(ride, selected, AppColors.primary, lang),
                                ),
                            ).animate(target: isHighlighted ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.05, 1.05));
                          },
                        ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),

          // Fixed Bottom Footer Area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 12,
                bottom: MediaQuery.of(context).padding.bottom + 16, // Extra space for navigation bar
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                   BoxShadow(
                     color: Colors.black.withValues(alpha: 0.05),
                     blurRadius: 10,
                     offset: const Offset(0, -5),
                   )
                ]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   // Book for Others Toggle
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20),
                     child: _bookForOthersToggle(context, vm, lang),
                   ),
                   const SizedBox(height: 12),
                   
                   // Payment Method Display
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20),
                     child: _paymentDisplay(lang),
                   ),
                   const SizedBox(height: 12),
                   
                   // Confirm Button
                   _confirmButton(context, vm, lang),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                const Icon(Icons.circle, color: Colors.green, size: 12),
                Expanded(
                  child: Container(
                    width: 226,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
                const Icon(Icons.square, color: Colors.red, size: 12),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    pickup,
                    maxLines: 1, // Reduced to 1
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13, // Reduced font
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination,
                    maxLines: 1, // Reduced to 1
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13, // Reduced font
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
    LanguageViewModel lang,
  ) {
    final bool isButtonDisabled =
        vm.isBooking || vm.isOutstationRide || !vm.isServiceAvailable || vm.selectedRide == null;

    final rideName = vm.selectedRide != null ? lang.getText(vm.selectedRide!.name) : "";

    return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Schedule Button
          if (!vm.isOutstationRide && !vm.isBooking)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () => _pickDateTime(context, vm),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today_outlined, 
                        color: vm.scheduledTime != null ? AppColors.primary : Colors.grey[600], size: 18),
                      const SizedBox(width: 8),
                      Text(
                        vm.scheduledTime == null 
                          ? lang.getText('schedule_later')
                          : "${lang.getText('schedule_later')}: ${_formatDate(vm.scheduledTime!)}",
                        style: TextStyle(
                          color: vm.scheduledTime != null ? AppColors.primary : Colors.grey[700],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 52, // Reduced from 58
              child: ElevatedButton(
                onPressed: isButtonDisabled
                    ? null
                    : () async {
                        if (vm.isBookForOthers && (vm.receiverName == null || vm.receiverPhone == null)) {
                           _showBookForOthersDialog(context, vm);
                           return;
                        }

                        await vm.bookRide(() async {
                          final parent = context.findAncestorWidgetOfExactType<RideSelectionScreen>();
                          await bookRideTransaction(
                            context, 
                            vm, 
                            pickupText: parent!.pickupText, 
                            destinationText: parent.destinationText
                          );
                        });
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: Colors.grey[300],
                  elevation: 6,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: vm.isBooking
                    ? const SizedBox(
                        height: 22, // Reduced
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, // Reduced
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        !vm.isServiceAvailable
                            ? "Service Unavailable"
                            : vm.isOutstationRide
                                ? lang.getText('beyond_service_limit')
                                : (vm.selectedRide == null
                                      ? lang.getText('select_ride')
                                      : "${lang.getText('book_now')} $rideName"),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16, // Reduced from 18
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ),
        ],
      );
  }

  Future<void> _pickDateTime(BuildContext context, RideSelectionViewModel vm) async {
    final now = DateTime.now();
    final firstDate = now.add(const Duration(minutes: 15)); // Min start time
    
    final date = await showDatePicker(
      context: context,
      initialDate: firstDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );

    if (date == null) return;

    if (!context.mounted) return;
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(firstDate),
    );

    if (time == null) return;

    final selected = DateTime(
      date.year, date.month, date.day, time.hour, time.minute
    );

    if (selected.isBefore(now)) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('select_future_time'))),
         );
       }
       return;
    }

    vm.setScheduledTime(selected);
  }

  String _formatDate(DateTime d) {
    return "${d.day}/${d.month} ${d.hour}:${d.minute.toString().padLeft(2,'0')}";
  }

  Widget _outstationMessage(LanguageViewModel lang) =>
      Center(child: Text(lang.getText('outstation_unavailable')));

  Widget _serviceUnavailableMessage(LanguageViewModel lang) =>
      Expanded(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                "Service Unavailable", 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "Rurboo is not currently operating in this area.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _paymentDisplay(LanguageViewModel lang) => InkWell(
    onTap: () {
      // payment selection
    },
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(lang.getText('payment_method'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Row(
            children: [
              Text(lang.getText('cash'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _bookForOthersToggle(BuildContext context, RideSelectionViewModel vm, LanguageViewModel lang) {
    return InkWell(
      onTap: () {
        if (!vm.isBookForOthers) {
          vm.setBookForOthers(true);
          _showBookForOthersDialog(context, vm);
        } else {
          vm.setBookForOthers(false);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: vm.isBookForOthers ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: vm.isBookForOthers ? AppColors.primary : Colors.grey[200]!)
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.person_add_alt, color: vm.isBookForOthers ? AppColors.primary : Colors.grey),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang.getText('book_for_someone_else'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (vm.isBookForOthers && vm.receiverName != null)
                      Text(
                        "${vm.receiverName} (${vm.receiverPhone})",
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      )
                  ],
                ),
              ],
            ),
            Switch(
              value: vm.isBookForOthers,
              onChanged: (val) {
                vm.setBookForOthers(val);
                if (val) _showBookForOthersDialog(context, vm);
              },
              activeTrackColor: AppColors.primary,
              activeThumbColor: AppColors.primary,
            )
          ],
        ),
      ),
    );
  }

/* 
  Widget _couponSection(BuildContext context, RideSelectionViewModel vm, LanguageViewModel lang) {
    ...
  }
*/

/*
  void _showCouponSheet(BuildContext context, RideSelectionViewModel vm) {
    ...
  }
*/

  Widget _rideTile(RideOption ride, bool selected, Color color, LanguageViewModel lang) {
    return Row(
      children: [
        // ICON
        if (ride.imageAsset != null)
          Image.asset(
            ride.imageAsset!,
            width: 44, // Reduced from 50
            height: 44,
            fit: BoxFit.contain,
          )
        else
          Icon(
            ride.icon, 
            size: 36, // Reduced from 40
            color: ride.iconColor ?? (selected ? AppColors.primary : Colors.grey[400]),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    lang.getText(ride.name),
                    style: TextStyle(
                      fontSize: 15, // Reduced from default
                      fontWeight: FontWeight.bold,
                      color: selected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (ride.id == 'car')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "AC",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.person, size: 10, color: Colors.grey[600]),
                  const SizedBox(width: 3),
                  Text(
                    ride.seats == 0 
                      ? lang.getText('cargo') 
                      : "${ride.seats} ${ride.seats > 1 ? lang.getText('seats') : lang.getText('seat')}", 
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                  const SizedBox(width: 3),
                  Text(
                    "${ride.eta} min", 
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 2),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              "₹${ride.fare.toInt()}",
              style: TextStyle(
                fontSize: 17, // Reduced from default
                fontWeight: FontWeight.w900,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showBookForOthersDialog(BuildContext context, RideSelectionViewModel vm) {
    final nameController = TextEditingController(text: vm.receiverName);
    final phoneController = TextEditingController(text: vm.receiverPhone);
    final lang = Provider.of<LanguageViewModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(lang.getText('book_for_someone_else')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: lang.getText('passenger_name'), prefixIcon: const Icon(Icons.person)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: lang.getText('phone_number'), prefixIcon: const Icon(Icons.phone)),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
               vm.setBookForOthers(false);
               Navigator.pop(c);
            },
            child: Text(lang.getText('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.length == 10) {
                vm.setReceiverDetails(nameController.text, phoneController.text);
                Navigator.pop(c);
              } else {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text(lang.getText('invalid_details'))),
                 );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: Text(lang.getText('confirm')),
          )
        ],
      ),
    );
  }
}

Future<void> bookRideTransaction(
  BuildContext context,
  RideSelectionViewModel vm, {
  required String pickupText,
  required String destinationText,
}) async {
  final connectivity = await Connectivity().checkConnectivity();
  if (connectivity.contains(ConnectivityResult.none)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('no_internet')),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final userId = await UserPreferences.getUserId();
    final authUser = FirebaseAuth.instance.currentUser;

    // 🔒 SECURITY CHECK
    if (userId == null || authUser == null || userId != authUser.uid) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('session_expired'))),
      );
      return; 
    }

    if (vm.selectedRide == null) {
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

    // ✅ SECURE OTP GENERATION (Refactored)
    // TODO: Move this to Cloud Function for maximum security
    final String otp = _generateSecureOTP();

    // ✅ ROBUST VEHICLE CATEGORIZATION
    final String category = _getVehicleCategory(vm.selectedRide!.name);

    final String finalUserName = vm.isBookForOthers ? (vm.receiverName ?? 'User') : (userData['name'] ?? 'User');
    final String finalUserPhone = vm.isBookForOthers ? (vm.receiverPhone ?? '') : (userData['phoneNumber'] ?? '');

    final rideData = {
      'userId': userId,
      'userName': finalUserName,
      'userPhone': finalUserPhone,
      'pickupAddress': pickupText,
      'destinationAddress': destinationText,
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
      'cartName': vm.selectedRide!.name, // Redundancy for old logic
      'vehicleCategory': category, // Uses cleaner helper
      'paymentMethod': vm.selectedPayment,
      'otp': otp,
      'status': vm.scheduledTime != null ? 'scheduled' : 'pending',
      'scheduledTime': vm.scheduledTime != null ? Timestamp.fromDate(vm.scheduledTime!) : null,
      'receiverName': vm.isBookForOthers ? vm.receiverName : null,
      'receiverPhone': vm.isBookForOthers ? vm.receiverPhone : null,
      'isBookForOthers': vm.isBookForOthers,
      'createdAt': FieldValue.serverTimestamp(),
      'discountAmount': vm.appliedCoupon != null ? vm.appliedCoupon!.amount : 0.0,
      'couponCode': vm.appliedCoupon?.code,
      'finalFare': vm.finalFare, // Store final discounted fare
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
            pickupAddress: pickupText,
            destinationLatLng: vm.destination.coordinates!,
            destinationAddress: destinationText,
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
      ).showSnackBar(SnackBar(content: Text("${Provider.of<LanguageViewModel>(context, listen: false).getText('booking_failed')}: $e")));
    }
  }
}

// --- HELPER METHODS ---

String _generateSecureOTP() {
  var rng = Random.secure();
  return (1000 + rng.nextInt(9000)).toString();
}

String _getVehicleCategory(String rideName) {
  final name = rideName.toLowerCase();
  
  // Strictly ordered checks to match Driver App registration options
  if (name.contains("bike") || name.contains("moto")) return "Bike taxi";
  if (name.contains("rickshaw") && name.contains("e-")) return "E-Rikshaw";
  if (name.contains("auto") || name.contains("rickshaw")) return "Auto Rikshaw";
  if (name.contains("big car") || name.contains("suv") || name.contains("sedan")) return "Big Car";
  
  // Default to Comfort Car if nothing specific matches
  return "Comfort Car";
}
