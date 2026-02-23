import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';


import '../../language/viewmodels/language_vm.dart';
import '../../navigation/views/main_navigator.dart';
import '../viewmodels/ride_booked_viewmodel.dart';
import '../repositories/ride_booked_repository.dart';
import '../../home/services/polyline_service.dart';
import '../models/ride_booking.dart';
import 'ride_summary_screen.dart';
import '../../safety/services/sos_service.dart';

import '../../voice/viewmodels/voice_agent_viewmodel.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
            SnackBar(
              content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('ride_cancelled_driver')),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('ride_cancelled_user')),
              backgroundColor: Colors.grey,
            ),
          );
        }
      };
      
      // Voice announcements only - no command handling
      // Listen for Ride Stage Changes using VM listener
      vm.addListener(_onRideStageChange);
    });
  }
  
  RideStage? _lastStage;
  
  void _onRideStageChange() {
    if (!mounted) return;
    if (vm.stage == _lastStage) return;
    
    _lastStage = vm.stage;
    final voice = Provider.of<VoiceAgentViewModel>(context, listen: false);
    
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    
    // Announce ride updates with comprehensive information
    if (vm.stage == RideStage.arriving) {
       // Driver found - announce with ETA
       final eta = vm.eta; 
       String msg = lang.getText('driver_arriving_voice');
       msg = msg.replaceAll('{0}', vm.rideDetails?.driverName ?? '');
       msg = msg.replaceAll('{1}', vm.rideDetails?.carNumber ?? '');
       msg = msg.replaceAll('{2}', eta);
       voice.speak(msg);
       
       // Check for Proactive Safety Alert on Arrival/Start
       _triggerSafetyVoiceCheck(vm, voice);
    } else if (vm.stage == RideStage.inProgress) {
       // Ride started - announce with destination ETA
       final eta = vm.eta; 
       String msg = lang.getText('ride_started_voice');
       msg = msg.replaceAll('{0}', eta);
       voice.speak(msg);
    } else if (vm.stage == RideStage.completed) {
       // Ride completed - thank you message
       voice.speak(lang.getText('ride_completed_voice'));
    }
  }
  
  void _triggerSafetyVoiceCheck(RideBookedViewModel vm, VoiceAgentViewModel voice) {
     final now = DateTime.now();
     final hour = now.hour;
     final bool isNight = hour >= 22 || hour <= 5; // 10 PM to 5 AM
     
     if (isNight && (vm.userCategory == 'Woman' || vm.userCategory == 'Child')) {
        // We delay slightly so it doesn't overlap with "Driver Arriving"
        Future.delayed(const Duration(seconds: 4), () {
           if (mounted && vm.stage == RideStage.arriving) {
             final lang = Provider.of<LanguageViewModel>(context, listen: false);
             voice.speak(lang.getText('safety_mode_voice'));
           }
        });
     }
  }

  @override
  void dispose() {
    vm.removeListener(_onRideStageChange); // Clean up
    super.dispose();
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
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('exit_warning')),
              duration: const Duration(seconds: 2),
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
                    // Old share button removed
                    const SizedBox(),

                    // Share moved to floating action button
                    const SizedBox(),
                  ],
                ),
              ),
            ),

            // Top Right: Safety Shield
            Positioned(
              top: 50,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'safety_shield',
                backgroundColor: Colors.white,
                foregroundColor: Colors.indigo,
                elevation: 4,
                onPressed: () => _showSafetyShield(context, vm),
                child: const Icon(Icons.shield_moon),
              ),
            ),

            // Top Right (Below Shield): Share Button
            Positioned(
              top: 110,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'share_btn',
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 3,
                child: const Icon(Icons.share, size: 20),
                onPressed: () {
                   // ignore: deprecated_member_use
                   Share.share(
                     "${Provider.of<LanguageViewModel>(context, listen: false).getText('share_msg_text')}\nhttps://rurboo.app/track?id=${vm.rideId}",
                   );
                },
              ),
            ),

            // Bottom Right (Above Panel): SOS Button (Pulsing/Prominent)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.50 + 20,
              left: 16,
              child: FloatingActionButton(
                heroTag: 'sos_btn',
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                elevation: 6,
                onPressed: () => SOSService().showSOSDialog(
                    context: context, 
                    rideId: vm.rideId,
                    guardianPhone: vm.guardianPhone,
                    trustedContacts: vm.trustedContacts,
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sos, size: 24),
                    Text("SOS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), // SOS is universal usually, but checking AppStrings... yes 'sos' exists
                  ],
                ),
              ),
            ),

            // End Ride Request Overlay
            if (vm.isEndRideRequested)
              Positioned(
                top: 150,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 40),
                      const SizedBox(height: 10),
                      Text(
                        Provider.of<LanguageViewModel>(context).getText('driver_requested_end_ride') ?? "Driver requested to end trip early.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        Provider.of<LanguageViewModel>(context).getText('driver_requested_end_desc') ?? "Please confirm if you have reached your destination securely.",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => vm.rejectEndRide(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: Text(Provider.of<LanguageViewModel>(context).getText('reject') ?? "Reject"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => vm.approveEndRide(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(Provider.of<LanguageViewModel>(context).getText('approve') ?? "Approve"),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              ),

            // Bottom Sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.55,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 30,
                      spreadRadius: 5,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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

                        // Status & Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: vm.stage == RideStage.arriving ? AppColors.primary.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                 borderRadius: BorderRadius.circular(20),
                               ),
                               child: Text(
                                 _getStatusText(vm.stage, Provider.of<LanguageViewModel>(context)),
                                 style: TextStyle(
                                   color: vm.stage == RideStage.arriving ? AppColors.primary : Colors.green[700],
                                   fontWeight: FontWeight.bold,
                                   fontSize: 14,
                                 ),
                               ),
                             ),
                             if (vm.stage == RideStage.arriving || vm.stage == RideStage.inProgress)
                               Text(
                                 vm.eta,
                                 style: const TextStyle(
                                   color: AppColors.textSecondary,
                                   fontWeight: FontWeight.w600,
                                   fontSize: 16,
                                 ),
                               ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Driver Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.grey[300]!),
                                  image: const DecorationImage(
                                     image: NetworkImage("https://cdn-icons-png.flaticon.com/512/3135/3135715.png"), // Placeholder driver
                                     fit: BoxFit.cover,
                                  ), 
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vm.rideDetails?.driverName ?? "Connecting...",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${vm.rideDetails?.carName} • ${vm.rideDetails?.carNumber}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.star, size: 14, color: AppColors.accent),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${vm.rideDetails?.rating ?? 5.0}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Chat/Call Actions
                              Column(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.call, color: AppColors.primary),
                                    onPressed: () => vm.callDriver(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      padding: const EdgeInsets.all(10),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        if (vm.stage == RideStage.arriving && vm.otp != null)
                        Container(
                           width: double.infinity,
                           margin: const EdgeInsets.only(bottom: 20),
                           padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                           decoration: BoxDecoration(
                             color: AppColors.surfaceDark,
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Row(
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Text(
                                 Provider.of<LanguageViewModel>(context).getText('otp'),
                                 style: const TextStyle(color: Colors.white70, fontSize: 14),
                               ),
                               Text(
                                 vm.otp!,
                                 style: const TextStyle(
                                   color: Colors.white,
                                   fontSize: 24,
                                   fontWeight: FontWeight.bold,
                                   letterSpacing: 4,
                                 ),
                               ),
                             ],
                           ),
                        ),

                        _buildTripLine(vm),

                        const SizedBox(height: 20),
                        
                        // Fare & Payment Info
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50], // Fixed
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.payment, color: Colors.indigo, size: 20),
                                      SizedBox(width: 8),
                                      Text(vm.rideDetails?.paymentMethod ?? "Cash", style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if ((vm.rideDetails?.discountAmount ?? 0) > 0)
                                        Text(
                                          "₹${vm.rideDetails!.fare.toInt()}",
                                          style: const TextStyle(
                                            decoration: TextDecoration.lineThrough,
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      Text(
                                        "₹${(vm.rideDetails!.fare - (vm.rideDetails?.discountAmount ?? 0)).clamp(0, double.infinity).toInt()}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if ((vm.rideDetails?.discountAmount ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Icon(Icons.discount, size: 12, color: Colors.green),
                                      SizedBox(width: 4),
                                      Text(
                                        "${lang.getText('referral_discount_applied')} (-₹${vm.rideDetails!.discountAmount.toInt()})",
                                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),

                        // Action Buttons
                        if (vm.stage != RideStage.inProgress && vm.stage != RideStage.completed)
                        Row(
                          children: [
                             Expanded(
                               child: OutlinedButton(
                                 onPressed: () => _showCancelDialog(context, vm),
                                 style: OutlinedButton.styleFrom(
                                   foregroundColor: AppColors.error,
                                   side: const BorderSide(color: Color(0xFFFFEBEE)),
                                   backgroundColor: const Color(0xFFFFEBEE),
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                 ),
                                 child: Text(Provider.of<LanguageViewModel>(context).getText('cancel')),
                               ),
                             ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(RideStage stage, LanguageViewModel lang) {
    switch (stage) {
      case RideStage.arriving:
        return lang.getText('status_arriving');
      case RideStage.inProgress:
        return lang.getText('status_inprogress');
      case RideStage.completed:
        return lang.getText('status_finished');
      case RideStage.cancelled:
        return lang.getText('status_aborted');
      default:
        return lang.getText('status_connecting');
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
            Text(
              Provider.of<LanguageViewModel>(context, listen: false).getText('cancel_ride_title'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              Provider.of<LanguageViewModel>(context, listen: false).getText('cancel_ride_conf'),
              style: const TextStyle(color: Colors.grey),
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
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('no_internet_cancel')),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  vm.cancelRide();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                child: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('yes_cancel')),
              ),
            ),

            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  Provider.of<LanguageViewModel>(context, listen: false).getText('dont_cancel'),
                  style: const TextStyle(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showSafetyShield(BuildContext context, RideBookedViewModel vm) {
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
            Row(
              children: [
                Icon(Icons.shield_moon, color: Colors.indigo, size: 28),
                SizedBox(width: 12),
                Text(
                  Provider.of<LanguageViewModel>(context, listen: false).getText('safety_shield_title'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Provider.of<LanguageViewModel>(context, listen: false).getText('safety_shield_subtitle'),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // 1. Share Ride
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.share, color: Colors.white, size: 20),
              ),
              title: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('share_trip_details')),
              subtitle: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('send_tracking_link')),
              onTap: () {
                Navigator.pop(ctx);
                // ignore: deprecated_member_use
                Share.share(
                    "${Provider.of<LanguageViewModel>(context, listen: false).getText('share_msg_text')}\nhttps://rurboo.app/track?id=${vm.rideId}");
              },
            ),
            const Divider(),

            // 2. Call Guardian
            if (vm.guardianPhone != null || vm.trustedContacts.isNotEmpty)
              ListTile(
                leading: const CircleAvatar(
                   backgroundColor: Colors.indigo,
                   child: Icon(Icons.contact_phone, color: Colors.white, size: 20),
                ),
                title: Text(Provider.of<LanguageViewModel>(context, listen: false).getText(vm.guardianPhone != null ? 'call_guardian' : 'call_contact')),
                onTap: () {
                  Navigator.pop(ctx); 
                  SOSService().showSOSDialog(
                    context: context, 
                    rideId: vm.rideId,
                    guardianPhone: vm.guardianPhone,
                    trustedContacts: vm.trustedContacts,
                  );
                },
              ),

            // 3. Emergency 112
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.local_police, color: Colors.white, size: 20),
              ),
              title: Text(Provider.of<LanguageViewModel>(context, listen: false).getText('emergency_call')),
              onTap: () {
                 Navigator.pop(ctx);
                 SOSService().showSOSDialog(
                    context: context, 
                    rideId: vm.rideId,
                    guardianPhone: vm.guardianPhone,
                    trustedContacts: vm.trustedContacts,
                 );
              },
            ),
          ],
        ),
      ),
    );
}
