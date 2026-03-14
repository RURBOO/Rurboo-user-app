import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RouteInfo {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMins;

  RouteInfo({
    required this.points,
    required this.distanceKm,
    required this.durationMins,
  });
}

class PolylineService {
  Future<RouteInfo?> getRouteData(LatLng start, LatLng end) async {
    final String apiKey = dotenv.get('GOOGLE_MAPS_API_KEY');
    
    final String origin = "${start.latitude},${start.longitude}";
    final String destination = "${end.latitude},${end.longitude}";

    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json?"
      "origin=$origin&"
      "destination=$destination&"
      "departure_time=now&"
      "traffic_model=best_guess&"
      "key=$apiKey"
    );

    try {
      debugPrint("🚀🚀🚀 GOOGLE DIRECTIONS GET: https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination...");
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] != 'OK' || (data['routes'] as List).isEmpty) {
          debugPrint("❌ Google Directions API Error Status: ${data['status']}");
          if (data['error_message'] != null) {
            debugPrint("❌ Error Message: ${data['error_message']}");
          }
          debugPrint("🔄 Falling back to OSRM...");
          return await _getOSRMRouteData(start, end);
        }

        final route = data['routes'][0];
        final leg = route['legs'][0];

        // 🛣️ Polyline Decoding
        final String encodedPoly = route['overview_polyline']['points'];
        List<PointLatLng> decodedPoints = PolylinePoints.decodePolyline(encodedPoly);
        final List<LatLng> points = decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
        
        debugPrint("🚀🚀🚀 Decoded Points Count: ${points.length}");

        // 📊 Distance & Duration (Traffic Aware)
        final double distMeters = (leg['distance']['value'] as num).toDouble();
        
        // Prefer duration_in_traffic if available
        final double durSeconds = (leg['duration_in_traffic']?['value'] ?? leg['duration']['value'] as num).toDouble();

        debugPrint("🚀🚀🚀 Google Parsed: ${distMeters/1000}km, ${durSeconds/60}mins (with traffic)");

        return RouteInfo(
          points: points,
          distanceKm: distMeters / 1000,
          durationMins: durSeconds / 60,
        );
      }
      debugPrint("❌ Google Directions Status Code: ${response.statusCode}. Falling back to OSRM...");
      return await _getOSRMRouteData(start, end);
    } catch (e) {
      if (kDebugMode) {
        debugPrint("Google Directions Service Error: $e. Falling back to OSRM...");
      }
      return await _getOSRMRouteData(start, end);
    }
  }

  Future<RouteInfo?> _getOSRMRouteData(LatLng start, LatLng end) async {
    final String startCoords = "${start.longitude},${start.latitude}";
    final String endCoords = "${end.longitude},${end.latitude}";

    final url = Uri.parse(
      "http://router.project-osrm.org/route/v1/driving/$startCoords;$endCoords?overview=full&geometries=geojson",
    );

    try {
      debugPrint("🚀 OSRM GET: $url");
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] == null || (data['routes'] as List).isEmpty) return null;

        final route = data['routes'][0];
        final geometry = route['geometry'];
        final coordinates = geometry['coordinates'] as List;

        final List<LatLng> points = coordinates.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();

        final double distMeters = (route['distance'] as num).toDouble();
        final double durSeconds = (route['duration'] as num).toDouble();

        debugPrint("🚀 OSRM Parsed: ${distMeters/1000}km, ${durSeconds/60}mins");

        return RouteInfo(
          points: points,
          distanceKm: distMeters / 1000,
          durationMins: durSeconds / 60,
        );
      }
      return null;
    } catch (e) {
      debugPrint("OSRM Fallback Error: $e");
      return null;
    }
  }
}
