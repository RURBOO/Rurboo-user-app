import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/recent_places.dart';
import '../services/location_service.dart';
import '../services/recent_places_service.dart';
import '../services/polyline_service.dart';

class HomeRepository {
  final LocationService locationService;
  final RecentPlacesService recentService;
  final PolylineService polylineService;

  HomeRepository({
    required this.locationService,
    required this.recentService,
    required this.polylineService,
  });

  Future<LatLng?> getCurrentLocation() => locationService.getCurrentLocation();

  Future<List<RecentPlace>> loadDestinations() =>
      recentService.loadDestinations();

  Future<void> saveDestination(RecentPlace place) =>
      recentService.saveDestination(place);

  Future<void> savePickup(RecentPlace place) => recentService.savePickup(place);

  Future<RecentPlace?> loadPickup() => recentService.loadPickup();

  Future<List<LatLng>> getPolyline(LatLng start, LatLng end) async {
    final routeInfo = await polylineService.getRouteData(start, end);
    return routeInfo?.points ?? [];
  }
}
