import 'dart:async';
import 'package:flutter/material.dart';
import '../repositories/search_repository.dart';
import '../../home/models/location_result.dart';

class SearchLocationViewModel extends ChangeNotifier {
  final SearchRepository repo;
  bool isDestinationMode;
  final String language;

  SearchLocationViewModel({
    required this.repo,
    required this.isDestinationMode,
    this.language = 'en',
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

  /// Switch active mode between pickup ↔ destination
  void switchMode(bool toDestination) {
    if (isDestinationMode == toDestination) return;
    isDestinationMode = toDestination;
    suggestions = []; // Clear previous suggestions on switch
    notifyListeners();
    // Trigger keyboard focus on the newly active field
    if (toDestination) {
      destinationFocus.requestFocus();
    } else {
      pickupFocus.requestFocus();
    }
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
    suggestions = await repo.autocomplete(query, language: language);
    loading = false;
    notifyListeners();
  }

  Future<LocationResult?> selectPlace(String placeId) async {
    try {
      loading = true;
      notifyListeners();
      final result = await repo.getPlaceDetails(placeId, language: language);
      loading = false;
      notifyListeners();
      return result;
    } catch (e) {
      loading = false;
      notifyListeners();
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
