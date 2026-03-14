import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
import '../models/service_zone.dart';

class ZoneService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache to store the zones for the session
  List<ServiceZone> _activeZones = [];
  bool _hasFetched = false;

  /// Fetches all active service regions from Firestore
  Future<List<ServiceZone>> getActiveZones({bool forceRefresh = false}) async {
    if (_hasFetched && !forceRefresh) {
      return _activeZones;
    }

    try {
      final snapshot = await _firestore
          .collection('service_zones')
          .where('isActive', isEqualTo: true)
          .get();

      if (snapshot.docs.isEmpty) {
        // Return empty list if no active zones are found
        return [];
      }

      _activeZones = snapshot.docs.map((doc) {
        return ServiceZone.fromMap(doc.data(), doc.id);
      }).toList();

      _hasFetched = true;
      debugPrint("📍 Loaded ${_activeZones.length} active service zones.");
      return _activeZones;
    } catch (e) {
      debugPrint("❌ Error fetching service zones: $e");
      return []; // Failsafe empty
    }
  }
}

