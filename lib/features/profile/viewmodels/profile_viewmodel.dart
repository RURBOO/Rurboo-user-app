import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/user_preferences.dart';
import '../../splash/views/splash_screen.dart';

class ProfileViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _userName;
  String? get userName => _userName;

  String? _email;
  String? get email => _email;

  String? _gender;
  String? get gender => _gender;

  int? _age;
  int? get age => _age;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;
  
  String? _photoUrl;
  String? get photoUrl => _photoUrl;
  
  int _totalRides = 0;
  int get totalRides => _totalRides;

  double _avgRating = 5.0;
  double get avgRating => _avgRating;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  ProfileViewModel() {
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = await UserPreferences.getUserId();

      if (userId == null) {
        throw Exception("User is not logged in.");
      }

      final docSnapshot = await _firestore.collection('users').doc(userId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        _userName = data?['name'] ?? 'Rurboo User';
        _email = data?['email'];
        _gender = data?['gender'];
        _age = data?['age'];
        _phoneNumber = data?['phoneNumber'] ?? '+91';
        _photoUrl = data?['photoUrl'];
        _totalRides = data?['totalRides'] ?? 0;
        _avgRating = (data?['rating'] ?? 5.0).toDouble();
      } else {
         // Create stub profile if missing
         _userName = "New User";
         _phoneNumber = _auth.currentUser?.phoneNumber ?? "";
      }
    } catch (e) {
      _errorMessage = "Error fetching profile: $e";
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfilePicture(BuildContext context) async {
    try {
        final XFile? image = await _picker.pickImage(
            source: ImageSource.gallery, 
            imageQuality: 70,
        );
        
        if (image == null) return;

        _isLoading = true;
        notifyListeners();

        final userId = await UserPreferences.getUserId();
        if (userId == null) throw Exception("User ID not found");

        File file = File(image.path);
        String fileName = 'profile_pics/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Upload to Firebase Storage
        TaskSnapshot snapshot = await _storage.ref(fileName).putFile(file);
        String downloadUrl = await snapshot.ref.getDownloadURL();

        // Update Firestore
        await _firestore.collection('users').doc(userId).update({
            'photoUrl': downloadUrl,
        });

        _photoUrl = downloadUrl;
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile Updated Successfully! 📸")),
          );
        }

    } catch (e) {
        debugPrint("Upload Error: $e");
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error: $e")),
          );
        }
    } finally {
        _isLoading = false;
        notifyListeners();
    }
  }

  Future<void> logout(BuildContext context) async {
    await UserPreferences.clearUserData();
    await _auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
        (route) => false,
      );
    }
  }
}
