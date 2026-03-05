import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../repositories/support_repository.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

class SupportViewModel extends ChangeNotifier {
  final SupportRepository _repository = SupportRepository();
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  XFile? _selectedImage;
  XFile? get selectedImage => _selectedImage;

  void pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      _selectedImage = image;
      notifyListeners();
    }
  }

  void clearImage() {
    _selectedImage = null;
    notifyListeners();
  }

  Stream<List<TicketModel>> getUserTickets() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      return _repository.getUserTickets(userId);
    } else {
      return Stream.value([]);
    }
  }

  Future<bool> createTicket({
    required String category,
    required String subject,
    required String description,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('support_tickets')
            .child('${const Uuid().v4()}.jpg');
        
        await storageRef.putFile(File(_selectedImage!.path));
        imageUrl = await storageRef.getDownloadURL();
      }

      final ticket = TicketModel(
        id: const Uuid().v4(),
        userId: userId,
        category: category,
        subject: subject,
        description: description,
        createdAt: DateTime.now(),
        status: 'Open',
        imageUrl: imageUrl,
        userType: 'user',
      );

      await _repository.createTicket(ticket);
      _selectedImage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
      return false;
    }
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}
