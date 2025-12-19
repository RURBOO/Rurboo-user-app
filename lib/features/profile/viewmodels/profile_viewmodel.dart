import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/services/user_preferences.dart';
import '../../splash/views/splash_screen.dart';

class ProfileViewModel extends ChangeNotifier {
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _userName;
  String? get userName => _userName;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = await UserPreferences.getUserId();

      if (userId == null) {
        throw Exception("User is not logged in.");
      }

      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _userName = data?['name'] ?? 'N/A';
        _phoneNumber = data?['phoneNumber'] ?? 'N/A';
      } else {
        throw Exception("User profile not found in the database.");
      }
    } catch (e) {
      _errorMessage = "Error fetching profile: $e";
      _userName = "Error";
      _phoneNumber = "Error";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> logout(BuildContext context) async {
    await UserPreferences.clearUserData();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }
}
