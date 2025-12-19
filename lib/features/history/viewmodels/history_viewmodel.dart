import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/user_preferences.dart';
import '../models/ride_history_model.dart';

class HistoryViewModel extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<RideHistoryModel> _rideHistory = [];
  List<RideHistoryModel> get rideHistory => _rideHistory;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRideHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = await UserPreferences.getUserId();
      if (userId == null) {
        throw Exception("User is not logged in.");
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('rideRequests')
          .where('userId', isEqualTo: userId)
          .where('status', whereIn: ['completed', 'cancelled', 'closed'])
          .orderBy('createdAt', descending: true)
          .get();

      _rideHistory = querySnapshot.docs
          .map((doc) => RideHistoryModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print("History Error: $e");
      }
      _errorMessage = "Failed to fetch ride history. Please try again.";
    }

    _isLoading = false;
    notifyListeners();
  }
}
