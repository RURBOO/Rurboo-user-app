import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolygonUtils {
  /// Standard Ray-Casting Algorithm to determine if a point is inside a polygon.
  /// Works by casting an imaginary ray from the point to the right, and counting
  /// the number of times it crosses a polygon edge. Odd = inside, Even = outside.
  static bool isPointInPolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.isEmpty || polygon.length < 3) return false;

    bool isInside = false;
    int j = polygon.length - 1;
    
    for (int i = 0; i < polygon.length; i++) {
        final pi = polygon[i];
        final pj = polygon[j];

        // Check if the ray crosses the edge
        final bool intersect = ((pi.longitude > point.longitude) != (pj.longitude > point.longitude)) &&
            (point.latitude < (pj.latitude - pi.latitude) * (point.longitude - pi.longitude) / (pj.longitude - pi.longitude) + pi.latitude);
            
        if (intersect) {
            isInside = !isInside;
        }
        j = i;
    }

    return isInside;
  }
}

