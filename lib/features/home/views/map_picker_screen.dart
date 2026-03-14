import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../language/viewmodels/language_vm.dart';
import '../repositories/search_repository.dart';
import '../viewmodels/home_viewmodel.dart';
import '../models/location_result.dart';
import '../../../core/theme/map_styles.dart';
import '../../../core/theme/theme_provider.dart';

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final SearchRepository _repo = SearchRepository();
  late LatLng _initialPosition;
  LatLng? _currentCenter;
  String _address = "Searching...";
  bool _isLoadingAddress = false;
  GoogleMapController? _mapController;
  String _language = 'en'; // Language for geocoding
  
  // Pin State
  Offset? _pinPosition;
  final GlobalKey _mapKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initialPosition = widget.initialLocation ??
        Provider.of<HomeViewModel>(context, listen: false).currentLocation ??
        const LatLng(28.6139, 77.2090);
    _currentCenter = _initialPosition;
    // Capture language so geocoding returns addresses in the active language
    try {
      _language = Provider.of<LanguageViewModel>(context, listen: false).language;
    } catch (_) {}
    _getAddress(_currentCenter!);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Initialize pin to center of screen after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _pinPosition = Offset(size.width / 2 - 24, size.height / 2 - 48); // Center - (iconSize/2)
        });
      }
    });
  }

  Future<void> _getAddress(LatLng point) async {
    // Capture lang reference BEFORE any await to avoid deactivated widget error
    final lang = Provider.of<LanguageViewModel>(context, listen: false);
    if (!_isLoadingAddress) setState(() => _isLoadingAddress = true);
    try {
      final result = await _repo.reverseGeocode(point, language: _language);
      if (mounted) {
        setState(() {
          _address = result;
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _address = lang.getText('could_not_fetch_address');
          _isLoadingAddress = false;
        });
      }
    }
  }

  void _confirmLocation() {
    if (_currentCenter != null) {
      Navigator.pop(
        context,
        LocationResult(
          address: _address,
          coordinates: _currentCenter,
        ),
      );
    }
  }

  Future<void> _updateLocationFromPin() async {
    if (_mapController == null || _pinPosition == null) return;
    
    // The tip of the icon is at bottom-center. 
    // Icon is 48x48. Top-Left is _pinPosition.
    // Tip is at (_pinPosition.dx + 24, _pinPosition.dy + 48)
    final screenCoordinate = ScreenCoordinate(
      x: (_pinPosition!.dx + 24).round(),
      y: (_pinPosition!.dy + 48).round(),
    );

    final latLng = await _mapController!.getLatLng(screenCoordinate);
    _currentCenter = latLng;
    _getAddress(latLng);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageViewModel>(context);
    
    // Initialize address string if it's the default "Searching..."
    if (_address == "Searching...") {
        _address = lang.getText('fetching_address');
    }

    return Scaffold(
      body: Stack(
        key: _mapKey,
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          // Custom Draggable Pin
          if (_pinPosition != null)
            Positioned(
              left: _pinPosition!.dx,
              top: _pinPosition!.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _pinPosition = _pinPosition! + details.delta;
                  });
                },
                onPanEnd: (_) {
                  _updateLocationFromPin();
                },
                child: const Icon(
                  Icons.location_on,
                  size: 48,
                  color: Colors.red,
                ).animate(target: _isLoadingAddress ? 1 : 0)
                 .shake(duration: 300.ms), // Shake when loading
              ),
            ),

          // Back Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Bottom Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(lang.getText('select_location_label'), style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isLoadingAddress 
                            ? Row(children: [const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: 8), Text(lang.getText('fetching_address'))])
                            : Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                   ),
                   const SizedBox(height: 10),
                   Text(lang.getText('drag_pin_hint'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                   const SizedBox(height: 20),
                   SizedBox(
                     width: double.infinity,
                     height: 50,
                     child: ElevatedButton(
                       onPressed: _isLoadingAddress ? null : _confirmLocation,
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                       child: Text(lang.getText('confirm_location_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     ),
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
