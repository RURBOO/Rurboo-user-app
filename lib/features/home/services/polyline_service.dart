import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    final String startCoords = "${start.longitude},${start.latitude}";
    final String endCoords = "${end.longitude},${end.latitude}";

    final url = Uri.parse(
      "http://router.project-osrm.org/route/v1/driving/$startCoords;$endCoords?overview=full&geometries=geojson",
    );

    try {
      if (kDebugMode) {
        print("Fetching Route: $url");
      }

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          return null;
        }

        final route = data['routes'][0];

        final geometry = route['geometry'];
        final coordinates = geometry['coordinates'] as List;

        final List<LatLng> points = coordinates.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();

        final double distMeters = (route['distance'] as num).toDouble();
        final double durSeconds = (route['duration'] as num).toDouble();

        return RouteInfo(
          points: points,
          distanceKm: distMeters / 1000,
          durationMins: durSeconds / 60,
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("OSRM Service Error: $e");
      }
      return null;
    }
  }
}
