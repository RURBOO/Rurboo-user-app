import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../home/services/polyline_service.dart';

class RideSelectionRepository {
  final PolylineService polyService = PolylineService();

  Future<RouteInfo?> getRouteDetails(LatLng start, LatLng end) async {
    return await polyService.getRouteData(start, end);
  }

  Future<Map<String, dynamic>> fetchRideRates() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('rates')
          .get();

      if (doc.exists && doc.data() != null) {
        return doc.data()!;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error fetching rates: $e");
      }
    }

    return {
      'bike': {'base_fare': 30, 'per_km': 6},
      'auto': {'base_fare': 50, 'per_km': 10},
      'car': {'base_fare': 100, 'per_km': 15},
    };
  }

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      "http://router.project-osrm.org/route/v1/driving/"
      "${start.longitude},${start.latitude};"
      "${end.longitude},${end.latitude}"
      "?overview=full&geometries=geojson",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] == null || (data['routes'] as List).isEmpty) {
          return [];
        }

        final geometry = data['routes'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;

        return coordinates.map((coord) {
          return LatLng(coord[1].toDouble(), coord[0].toDouble());
        }).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print("OSRM Route Error: $e");
      }
      return [];
    }
  }
}
