import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../features/home/models/location_result.dart';
import '../../features/home/services/polyline_service.dart';
import '../../features/home/viewmodels/home_viewmodel.dart';
import '../../core/navigation/app_router.dart';
import '../../features/ride/models/ride_booking.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  late GlobalKey<NavigatorState> _navigatorKey;
  bool _isListening = false;
  
  // Store pending location to resume after login
  LocationResult? _pendingDestination;
  String? _pendingRideId;

  void init(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    if (_isListening) return;

    _isListening = true;
    _checkInitialLink();
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint("⚠️ Deep Link Error: $e");
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    debugPrint("🔗 Deep Link Received: $uri");
    Uri finalUri = uri;

    // 1. Expand Short URLs (goo.gl, maps.app.goo.gl)
    if (uri.host.contains('goo.gl') || uri.host == 'maps.app.goo.gl') {
      final expanded = await _expandShortUrl(uri);
      if (expanded != null) finalUri = expanded;
    }

    // 2. Check for Ride Tracking Link
    String? rideId = _extractRideId(finalUri);
    if (rideId != null) {
      _navigateToRideTracking(rideId);
      return;
    }

    // 3. Parse Coordinates or Query (Legacy Share Location)
    LatLng? coords = _extractCoordinates(finalUri);
    String? query = _extractQuery(finalUri);

    // 4. Fallback: Geocode Query if no Coords
    if (coords == null && query != null) {
      coords = await _geocodeQuery(query);
    }

    if (coords != null) {
      _navigateToRide(coords, query ?? "Shared Location");
    } else {
      debugPrint("❌ Could not extract location from link");
    }
  }

  Future<Uri?> _expandShortUrl(Uri shortUrl) async {
    try {
      final client = http.Client();
      final request = http.Request('HEAD', shortUrl);
      request.followRedirects = false;
      
      final response = await client.send(request);
      final location = response.headers['location'];
      
      if (location != null) {
        debugPrint("🔗 Expanded URL: $location");
        return Uri.parse(location);
      }
    } catch (e) {
      debugPrint("⚠️ URL Expansion Failed: $e");
    }
    return null;
  }

  String? _extractRideId(Uri uri) {
    // Matches https://rurboo.app/track?id=xyz
    // or rurboo://track?id=xyz
    if (uri.path.contains('track') && uri.queryParameters.containsKey('id')) {
      return uri.queryParameters['id'];
    }
    return null;
  }

  LatLng? _extractCoordinates(Uri uri) {
    // A. "geo:lat,lng"
    if (uri.scheme == 'geo') {
      final parts = uri.path.split(',');
      if (parts.length >= 2) {
        return LatLng(double.parse(parts[0]), double.parse(parts[1]));
      }
    }

    // B. Google Maps URL regex (Standard)
    final regExp = RegExp(r'([-+]?\d{1,2}\.\d+),\s*([-+]?\d{1,3}\.\d+)');
    final match = regExp.firstMatch(uri.toString());

    if (match != null) {
      return LatLng(
        double.parse(match.group(1)!),
        double.parse(match.group(2)!),
      );
    }

    // C. Query Parameters ?q=lat,lng
    if (uri.queryParameters.containsKey('q')) {
      final q = uri.queryParameters['q']!;
      final qMatch = regExp.firstMatch(q);
      if (qMatch != null) {
        return LatLng(
          double.parse(qMatch.group(1)!),
          double.parse(qMatch.group(2)!),
        );
      }
    }

    return null;
  }

  String? _extractQuery(Uri uri) {
    if (uri.queryParameters.containsKey('q')) {
      return uri.queryParameters['q'];
    }
    if (uri.queryParameters.containsKey('query')) {
      return uri.queryParameters['query'];
    }
    // Handle path-based queries like /maps/place/Pizza+Hut
    if (uri.pathSegments.contains('place')) {
      final index = uri.pathSegments.indexOf('place');
      if (index + 1 < uri.pathSegments.length) {
        return uri.pathSegments[index + 1].replaceAll('+', ' ');
      }
    }
    return null;
  }

  Future<LatLng?> _geocodeQuery(String query) async {
    try {
      debugPrint("🔍 Geocoding Query: $query");
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      debugPrint("⚠️ Geocoding Warning: $e");
    }
    return null;
  }

  void _navigateToRideTracking(String rideId) async {
     final context = _navigatorKey.currentContext;
     if (context == null) return;
     
     final user = FirebaseAuth.instance.currentUser;
     
     if (user == null) {
        _pendingRideId = rideId;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please Login to track ride")),
        );
        return;
     }
     
     _launchTrackingScreen(rideId);
  }

  void _launchTrackingScreen(String rideId) async {
      final context = _navigatorKey.currentContext;
      if (context == null) return;

      debugPrint("🚀 Launching Tracking for Ride: $rideId");
      
      try {
          // Fetch Ride Details
          final doc = await FirebaseFirestore.instance.collection('rideRequests').doc(rideId).get();
          
          if (!doc.exists) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Ride not found or expired")),
                );
              }
              return;
          }
          
          final data = doc.data() as Map<String, dynamic>;
          
          final pickupGp = data['pickupCoords'] as GeoPoint;
          final destGp = data['destinationCoords'] as GeoPoint;
          
          final ride = RideBookingModel(
            driverName: data['driverName'] ?? "Driver",
            driverPhone: data['driverPhone'] ?? "", 
            carName: data['carName'] ?? "Car",
            carNumber: data['carNumber'] ?? "",
            rating: (data['driverRating'] ?? 5.0).toDouble(),
            fare: (data['fare'] ?? 0).toDouble(),
            paymentMethod: data['paymentMethod'] ?? "Cash",
          );
          
          _navigatorKey.currentState?.pushNamed(
              AppRoutes.rideTracking,
              arguments: {
                'pickupLatLng': LatLng(pickupGp.latitude, pickupGp.longitude),
                'pickupAddress': data['pickupAddress'] ?? "Pickup",
                'destinationLatLng': LatLng(destGp.latitude, destGp.longitude),
                'destinationAddress': data['destinationAddress'] ?? "Destination",
                'ride': ride,
                'rideId': rideId,
              }
          );

      } catch (e) {
          debugPrint("❌ Tracking Error: $e");
      }
  }

  void _navigateToRide(LatLng destCoords, String destName) async {
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final user = FirebaseAuth.instance.currentUser;
    
    final destination = LocationResult(
      address: destName, 
      coordinates: destCoords,
    );

    if (user == null) {
      debugPrint("🔒 User not logged in. Pending navigation.");
      _pendingDestination = destination;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please Login to view shared ride")),
      );
    } else {
      _launchRideSelection(destination);
    }
  }

  void resumePendingNavigation() {
    if (_pendingDestination != null) {
      _launchRideSelection(_pendingDestination!);
      _pendingDestination = null;
    }
    if (_pendingRideId != null) {
      _launchTrackingScreen(_pendingRideId!);
      _pendingRideId = null;
    }
  }

  void _launchRideSelection(LocationResult destination) async {
    debugPrint("🚀 Launching Ride Selection for: ${destination.address}");
    
    final context = _navigatorKey.currentContext;
    if (context == null) return;

    final homeVm = Provider.of<HomeViewModel>(context, listen: false);
    
    await homeVm.init(context); 
    if (homeVm.currentLocation == null) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Fetching current location...")),
        );
       }
      return; 
    }

    final pickup = LocationResult(
      address: homeVm.pickupAddress ?? "Current Location",
      coordinates: homeVm.currentLocation!,
    );

    final polyService = PolylineService();
    final route = await polyService.getRouteData(pickup.coordinates!, destination.coordinates!);
    double dist = route?.distanceKm ?? 0;
    
    if (!context.mounted) return;

    _navigatorKey.currentState?.pushNamed(
      AppRoutes.rideSelection,
      arguments: {
        'pickupText': pickup.address,
        'destinationText': destination.address,
        'pickupLoc': pickup,
        'destinationLoc': destination,
        'distanceKm': dist,
      },
    );
  }
}
