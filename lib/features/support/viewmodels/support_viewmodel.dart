import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../repositories/support_repository.dart';
import '../../../core/services/user_preferences.dart';
import 'package:uuid/uuid.dart';

class SupportViewModel extends ChangeNotifier {
  final SupportRepository _repository = SupportRepository();
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Stream<List<TicketModel>> getUserTickets() {
    return Stream.fromFuture(UserPreferences.getUserId()).asyncExpand((userId) {
      if (userId != null) {
        return _repository.getUserTickets(userId);
      } else {
        return Stream.value([]);
      }
    });
  }

  Future<bool> createTicket({
    required String category,
    required String subject,
    required String description,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final userId = await UserPreferences.getUserId();
      if (userId == null) throw Exception("User not logged in");

      final ticket = TicketModel(
        id: const Uuid().v4(),
        userId: userId,
        category: category,
        subject: subject,
        description: description,
        createdAt: DateTime.now(),
        status: 'Open',
      );

      await _repository.createTicket(ticket);
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
