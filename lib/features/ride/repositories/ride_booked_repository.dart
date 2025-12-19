import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../home/services/polyline_service.dart';

class RideBookedRepository {
  final PolylineService polyService;

  RideBookedRepository({required this.polyService});

  Future<List<LatLng>> loadRoute(LatLng start, LatLng end) async {
    final routeInfo = await polyService.getRouteData(start, end);
    return routeInfo?.points ?? [];
  }
}
