import 'package:google_maps_flutter/google_maps_flutter.dart';

class ServiceZone {
  final String id;
  final String name;
  final bool isActive;
  final List<LatLng> polygon;

  ServiceZone({
    required this.id,
    required this.name,
    required this.isActive,
    required this.polygon,
  });

  factory ServiceZone.fromMap(Map<String, dynamic> map, String id) {
    List<LatLng> parsedPolygon = [];
    if (map['coordinates'] != null) {
      final List<dynamic> coords = map['coordinates'];
      parsedPolygon = coords.map((c) {
        return LatLng(
          (c['lat'] as num).toDouble(),
          (c['lng'] as num).toDouble(),
        );
      }).toList();
    }

    return ServiceZone(
      id: id,
      name: map['name'] ?? 'Unknown Area',
      isActive: map['isActive'] ?? false,
      polygon: parsedPolygon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isActive': isActive,
      'coordinates': polygon.map((latLng) => {
        'lat': latLng.latitude,
        'lng': latLng.longitude,
      }).toList(),
    };
  }
}
