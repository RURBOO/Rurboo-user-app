import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/search_repository.dart';
import '../../home/models/location_result.dart';

class SearchLocationViewModel extends ChangeNotifier {
  final SearchRepository repo;
  final bool isDestinationMode;

  SearchLocationViewModel({
    required this.repo,
    required this.isDestinationMode,
  });

  final pickupController = TextEditingController();
  final destinationController = TextEditingController();
  final pickupFocus = FocusNode();
  final destinationFocus = FocusNode();

  List<LocationResult> suggestions = [];
  bool loading = false;
  Timer? _debounce;

  void init(String? pickup, String? destination) {
    pickupController.text = pickup ?? '';
    destinationController.text = destination ?? '';
  }

  void onTextChanged(String query) {
    _debounce?.cancel();
    if (query.isEmpty) {
      suggestions = [];
      notifyListeners();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    loading = true;
    notifyListeners();

    suggestions = await repo.autocomplete(query);

    loading = false;
    notifyListeners();
  }

  Future<LocationResult?> selectPlace(String placeId) async {
    try {
      final selected = suggestions.firstWhere((p) => p.placeId == placeId);
      return selected;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    pickupController.dispose();
    destinationController.dispose();
    pickupFocus.dispose();
    destinationFocus.dispose();
    super.dispose();
  }
}
