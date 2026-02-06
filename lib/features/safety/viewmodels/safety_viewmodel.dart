import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SafetyViewModel extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<Map<String, dynamic>> _trustedContacts = [];
  List<Map<String, dynamic>> get trustedContacts => _trustedContacts;

  bool _safetyMode = false;
  bool get safetyMode => _safetyMode;

  SafetyViewModel() {
    _loadSafetySettings();
  }

  Future<void> _loadSafetySettings() async {
    final user = _auth.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        _safetyMode = data['safetyModeEnabled'] ?? false;
        
        if (data['trustedContacts'] != null) {
          _trustedContacts = List<Map<String, dynamic>>.from(data['trustedContacts']);
        }
      }
    } catch (e) {
      debugPrint("Error loading safety settings: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> toggleSafetyMode(bool value) async {
    final user = _auth.currentUser;
    if (user == null) return;

    _safetyMode = value;
    notifyListeners();

    await _firestore.collection('users').doc(user.uid).update({
      'safetyModeEnabled': value,
    });
  }

  Future<void> addTrustedContact(String name, String phone) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final newContact = {'name': name, 'phone': phone};
    _trustedContacts.add(newContact);
    notifyListeners();

    await _firestore.collection('users').doc(user.uid).update({
      'trustedContacts': FieldValue.arrayUnion([newContact]),
    });
  }

  Future<void> removeTrustedContact(int index) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final contactToRemove = _trustedContacts[index];
    _trustedContacts.removeAt(index);
    notifyListeners();

    await _firestore.collection('users').doc(user.uid).update({
      'trustedContacts': FieldValue.arrayRemove([contactToRemove]),
    });
  }
}
